-- 11_growth_quality_score.sql
-- Sai Sourabh Akula
-- Single quality verdict per segment (platform x borough x time of day).
-- Four dimensions, 25 pts each: margin, service, compliance, price stability.
-- Margin uses both aggregate take rate AND % of trips losing money,
-- since a few big trips can mask widespread negative margins.
--
-- Lyft: 0 vulnerable segments, 63% of trips in SOLID segments.
-- Uber: 13 vulnerable segments covering 46% of December volume.
-- Worst: Uber Brooklyn Late Night, score 25.

USE nyc_rideshare;

WITH segment_base AS (
    SELECT
        company_name,
        pu_borough                                      AS borough,
        time_of_day,

        COUNT(*)                                        AS total_trips,
        ROUND(AVG(base_passenger_fare), 2)              AS avg_base_fare,
        ROUND(
            (SUM(base_passenger_fare) - SUM(driver_pay))
            / NULLIF(SUM(base_passenger_fare), 0) * 100
        , 2)                                            AS avg_take_rate_pct,
        ROUND(
            SUM(CASE WHEN take_rate_pct < 0 THEN 1 ELSE 0 END)
            * 100.0 / COUNT(*)
        , 2)                                            AS negative_take_rate_pct,
        ROUND(AVG(sla_5min_met) * 100, 2)               AS sla_pct,
        ROUND(AVG(request_to_pickup_min), 2)            AS avg_wait_min,
        ROUND(AVG(below_tlc_minimum) * 100, 2)          AS violation_pct,
        ROUND(STDDEV(base_passenger_fare)
              / NULLIF(AVG(base_passenger_fare), 0) * 100, 1)
                                                        AS price_volatility_pct,
        ROUND(AVG(driver_pay_per_hour), 2)              AS avg_driver_hourly

    FROM v_trips_enriched
    WHERE pu_borough IS NOT NULL
      AND below_tlc_minimum IS NOT NULL
    GROUP BY company_name, pu_borough, time_of_day
    HAVING COUNT(*) >= 30
),

scored AS (
    SELECT
        *,

        -- margin health (0-25)
        CASE
            WHEN avg_take_rate_pct >= 20
                 AND negative_take_rate_pct < 5  THEN 25
            WHEN avg_take_rate_pct >= 15
                 AND negative_take_rate_pct < 10 THEN 20
            WHEN avg_take_rate_pct >= 10
                 AND negative_take_rate_pct < 15 THEN 15
            WHEN avg_take_rate_pct >= 5          THEN 10
            WHEN avg_take_rate_pct >= 0          THEN 5
            ELSE                                      0
        END                                             AS margin_score,

        -- service quality (0-25)
        CASE
            WHEN sla_pct >= 65 AND avg_wait_min <= 4.5 THEN 25
            WHEN sla_pct >= 60 AND avg_wait_min <= 5.0 THEN 20
            WHEN sla_pct >= 55 AND avg_wait_min <= 5.5 THEN 15
            WHEN sla_pct >= 50                         THEN 10
            WHEN sla_pct >= 40                         THEN 5
            ELSE                                            0
        END                                             AS service_score,

        -- driver compliance (0-25)
        CASE
            WHEN violation_pct = 0                     THEN 25
            WHEN violation_pct < 0.25                  THEN 20
            WHEN violation_pct < 0.5                   THEN 15
            WHEN violation_pct < 1.0                   THEN 10
            WHEN violation_pct < 2.0                   THEN 5
            ELSE                                            0
        END                                             AS compliance_score,

        -- price stability (0-25)
        CASE
            WHEN price_volatility_pct < 30             THEN 25
            WHEN price_volatility_pct < 45             THEN 20
            WHEN price_volatility_pct < 60             THEN 15
            WHEN price_volatility_pct < 75             THEN 10
            ELSE                                            5
        END                                             AS stability_score

    FROM segment_base
),

final_scored AS (
    SELECT
        *,
        (margin_score + service_score + compliance_score + stability_score)
                                                        AS growth_quality_score,

        RANK() OVER (
            ORDER BY
                (margin_score + service_score + compliance_score + stability_score)
                DESC
        )                                               AS quality_rank,

        RANK() OVER (
            PARTITION BY company_name
            ORDER BY
                (margin_score + service_score + compliance_score + stability_score)
                DESC
        )                                               AS quality_rank_within_platform

    FROM scored
)

-- full segment quality ranking
SELECT
    'Growth Quality Score'                              AS section,
    company_name,
    borough,
    time_of_day,
    total_trips,
    avg_base_fare,
    avg_take_rate_pct,
    negative_take_rate_pct,
    sla_pct,
    avg_wait_min,
    violation_pct,
    price_volatility_pct,
    avg_driver_hourly,
    margin_score,
    service_score,
    compliance_score,
    stability_score,
    growth_quality_score,
    quality_rank,
    quality_rank_within_platform,

    CASE
        WHEN growth_quality_score >= 80 THEN 'SUSTAINABLE'
        WHEN growth_quality_score >= 60 THEN 'SOLID'
        WHEN growth_quality_score >= 40 THEN 'FRAGILE'
        ELSE                                 'VULNERABLE'
    END                                                 AS strategic_verdict

FROM final_scored
ORDER BY growth_quality_score DESC;


-- platform summary
SELECT
    'Platform Quality Summary'                          AS section,
    company_name,
    ROUND(AVG(growth_quality_score), 1)                 AS avg_quality_score,
    ROUND(AVG(margin_score), 1)                         AS avg_margin_score,
    ROUND(AVG(service_score), 1)                        AS avg_service_score,
    ROUND(AVG(compliance_score), 1)                     AS avg_compliance_score,
    ROUND(AVG(stability_score), 1)                      AS avg_stability_score,
    COUNT(CASE WHEN growth_quality_score >= 80 THEN 1 END)
                                                        AS sustainable_segments,
    COUNT(CASE WHEN growth_quality_score < 40  THEN 1 END)
                                                        AS vulnerable_segments,
    COUNT(*)                                            AS total_segments

FROM final_scored
GROUP BY company_name
ORDER BY avg_quality_score DESC;
