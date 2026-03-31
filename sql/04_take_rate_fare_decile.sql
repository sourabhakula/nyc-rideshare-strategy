-- Margin breakdown by fare decile
-- Sai Sourabh Akula
--
-- Looking for where Uber's ~18% negative take rate trips are hiding.
-- Expected short cheap rides where TLC minimum pay exceeds the fare.
-- Wrong. Problem peaks in deciles 4-6 ($13-$24 fares). D1 is fine.
-- Looks like a mid-range pricing algorithm gap, not a minimum pay issue.
--
-- NTILE partitioned by platform so each gets its own decile bands.
-- D10 alone accounts for 49.7% of Uber's monthly margin.

USE nyc_rideshare;

WITH deciled AS (
    SELECT
        company_name,
        base_passenger_fare,
        driver_pay,
        take_rate_pct,
        platform_spread,
        pu_borough,
        time_of_day,
        trip_miles,

        NTILE(10) OVER (
            PARTITION BY company_name
            ORDER BY base_passenger_fare
        )                                               AS fare_decile

    FROM v_trips_enriched
    WHERE take_rate_pct IS NOT NULL
),

decile_summary AS (
    SELECT
        company_name,
        fare_decile,

        COUNT(*)                                        AS trips_in_decile,
        ROUND(MIN(base_passenger_fare), 2)              AS fare_min,
        ROUND(MAX(base_passenger_fare), 2)              AS fare_max,
        ROUND(AVG(base_passenger_fare), 2)              AS avg_base_fare,
        ROUND(AVG(driver_pay), 2)                       AS avg_driver_pay,
        ROUND(
            (SUM(base_passenger_fare) - SUM(driver_pay))
            / NULLIF(SUM(base_passenger_fare), 0) * 100
        , 2)                                            AS avg_take_rate_pct,
        ROUND(AVG(platform_spread), 2)                  AS avg_platform_spread,
        ROUND(AVG(trip_miles), 2)                       AS avg_miles,

        SUM(CASE WHEN take_rate_pct < 0  THEN 1 ELSE 0 END)
                                                        AS negative_take_rate_trips,
        ROUND(
            SUM(CASE WHEN take_rate_pct < 0 THEN 1 ELSE 0 END)
            * 100.0 / COUNT(*)
        , 2)                                            AS negative_take_rate_pct,

        ROUND(SUM(platform_spread), 0)                  AS total_margin,

        CASE
            WHEN AVG(take_rate_pct) >= 20  THEN 'HEALTHY'
            WHEN AVG(take_rate_pct) >= 10  THEN 'MODERATE'
            WHEN AVG(take_rate_pct) >= 0   THEN 'THIN'
            ELSE                                'LOSS MAKING'
        END                                             AS margin_health

    FROM deciled
    GROUP BY company_name, fare_decile
)

SELECT
    'Decile Summary'                                    AS section,
    company_name,
    fare_decile,
    CONCAT('$', fare_min, ' to $', fare_max)            AS fare_range,
    trips_in_decile,
    avg_base_fare,
    avg_driver_pay,
    avg_take_rate_pct,
    avg_platform_spread,
    avg_miles,
    negative_take_rate_trips,
    negative_take_rate_pct,
    total_margin,
    margin_health
FROM decile_summary
ORDER BY company_name, fare_decile;
