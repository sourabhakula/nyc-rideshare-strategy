-- 09_price_volatility.sql
-- Sai Sourabh Akula
--
-- Fare variance by zone and borough.
--
-- Using coefficient of variation (stddev / mean * 100) rather than raw stddev.
-- The reason: zones with high average fares will always show bigger stddev
-- just from scale. CV normalizes for that so you can actually compare
-- volatility across zones with very different price levels.
--
-- Minimum 30 trips per zone. Below that, one unusual trip (like a long
-- airport run through a normally short-trip zone) can make the CV look
-- massive when it's really just noise.
--
-- Part 3 isolates Late Night specifically because that's when supply is
-- tightest and surge conditions are most likely. Confirmed worst performer:
-- Staten Island Late Night -- 38% fare premium with 19% SLA for Lyft.
-- That's a broken market.

USE nyc_rideshare;

WITH zone_stats AS (
    SELECT
        pu_borough                                      AS borough,
        pu_zone                                         AS zone,
        company_name,
        COUNT(*)                                        AS total_trips,
        ROUND(AVG(base_passenger_fare), 2)              AS avg_fare,
        ROUND(STDDEV(base_passenger_fare), 2)           AS fare_stddev,
        ROUND(MIN(base_passenger_fare), 2)              AS fare_min,
        ROUND(MAX(base_passenger_fare), 2)              AS fare_max,
        ROUND(MAX(base_passenger_fare)
              - MIN(base_passenger_fare), 2)            AS fare_range,

        ROUND(
            STDDEV(base_passenger_fare)
            / NULLIF(AVG(base_passenger_fare), 0) * 100
        , 1)                                            AS coeff_of_variation_pct,

        ROUND(AVG(sla_5min_met) * 100, 2)               AS sla_pct,
        ROUND(
            (SUM(base_passenger_fare) - SUM(driver_pay))
            / NULLIF(SUM(base_passenger_fare), 0) * 100
        , 2)                                            AS avg_take_rate_pct

    FROM v_trips_enriched
    WHERE pu_zone IS NOT NULL
    GROUP BY pu_borough, pu_zone, company_name
    HAVING COUNT(*) >= 30
)

SELECT
    'Zone Volatility'                                   AS section,
    borough,
    zone,
    company_name,
    total_trips,
    avg_fare,
    fare_stddev,
    fare_min,
    fare_max,
    fare_range,
    coeff_of_variation_pct,
    sla_pct,
    avg_take_rate_pct,

    CASE
        WHEN coeff_of_variation_pct >= 60 THEN 'HIGH VOLATILITY'
        WHEN coeff_of_variation_pct >= 35 THEN 'MODERATE VOLATILITY'
        ELSE                                   'STABLE'
    END                                                 AS volatility_class,

    -- entry signal: stable pricing + decent volume + incumbent underperforming
    CASE
        WHEN coeff_of_variation_pct < 35
             AND total_trips >= 100
             AND sla_pct < 58
        THEN 'ENTRY OPPORTUNITY'
        WHEN coeff_of_variation_pct >= 60
             AND sla_pct < 55
        THEN 'VOLATILE AND UNDERSERVED'
        ELSE 'STANDARD'
    END                                                 AS entry_signal

FROM zone_stats
ORDER BY coeff_of_variation_pct DESC
LIMIT 40;


-- Borough-level volatility
SELECT
    'Borough Volatility'                                AS section,
    pu_borough                                          AS borough,
    company_name,
    COUNT(*)                                            AS total_trips,
    ROUND(AVG(base_passenger_fare), 2)                  AS avg_fare,
    ROUND(STDDEV(base_passenger_fare), 2)               AS fare_stddev,
    ROUND(
        STDDEV(base_passenger_fare)
        / NULLIF(AVG(base_passenger_fare), 0) * 100
    , 1)                                                AS coeff_of_variation_pct,
    ROUND(AVG(sla_5min_met) * 100, 2)                   AS sla_pct

FROM v_trips_enriched
WHERE pu_borough IS NOT NULL
GROUP BY pu_borough, company_name
ORDER BY coeff_of_variation_pct DESC;


-- Late Night specifically -- the highest stress window
SELECT
    'Late Night Volatility'                             AS section,
    pu_borough                                          AS borough,
    company_name,
    COUNT(*)                                            AS total_trips,
    ROUND(AVG(base_passenger_fare), 2)                  AS avg_fare,
    ROUND(STDDEV(base_passenger_fare), 2)               AS fare_stddev,
    ROUND(
        STDDEV(base_passenger_fare)
        / NULLIF(AVG(base_passenger_fare), 0) * 100
    , 1)                                                AS coeff_of_variation_pct,
    ROUND(AVG(sla_5min_met) * 100, 2)                   AS sla_pct,
    ROUND(AVG(request_to_pickup_min), 2)                AS avg_wait_min

FROM v_trips_enriched
WHERE time_of_day = 'Late Night'
  AND pu_borough IS NOT NULL
GROUP BY pu_borough, company_name
ORDER BY sla_pct ASC;
