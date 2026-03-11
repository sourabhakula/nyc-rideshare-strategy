-- 06_driver_pay_stress_test.sql
-- Sai Sourabh Akula
--
-- TLC minimum pay compliance check.
-- Formula: $0.82/mile + $0.57/min
-- The below_tlc_minimum flag is already set in the view, so this is
-- mostly aggregation work.
--
-- Uber came in at 1.05% violation rate, Lyft at 0.02%.
-- That's 750 vs 5 trips. 52:1 ratio isn't explained by volume alone --
-- Uber does 2.6x more trips but 150x more violations.
--
-- The counterintuitive part: violations are worst on LONG trips, not short ones.
-- I expected the opposite. The mechanism is the time component of the formula --
-- a 60-minute trip in slow traffic generates $34+ in minimum pay just from time.
-- If the fare was set before traffic conditions materialized, it won't cover that.
--
-- Avg shortfall on Uber violations is $5.11.
-- 750 violations x $5.11 = ~$3,832 in underpaid driver earnings in one month.
-- Small absolute number but completely preventable.

USE nyc_rideshare;

-- Platform level compliance overview
SELECT
    'Platform Summary'                                  AS section,
    company_name,
    COUNT(*)                                            AS total_trips,
    SUM(below_tlc_minimum)                              AS violation_trips,
    ROUND(AVG(below_tlc_minimum) * 100, 2)              AS violation_pct,

    ROUND(AVG(driver_pay), 2)                           AS avg_driver_pay,
    ROUND(AVG(driver_pay_per_hour), 2)                  AS avg_driver_hourly,
    ROUND(AVG(trip_miles), 2)                           AS avg_miles,
    ROUND(AVG(trip_min), 2)                             AS avg_trip_min,

    ROUND(AVG(trip_miles * 0.82 + trip_min * 0.57), 2)  AS avg_tlc_minimum_due,

    ROUND(
        AVG(CASE
            WHEN below_tlc_minimum = 1
            THEN (trip_miles * 0.82 + trip_min * 0.57) - driver_pay
        END)
    , 2)                                                AS avg_shortfall_on_violations

FROM v_trips_enriched
WHERE below_tlc_minimum IS NOT NULL
GROUP BY company_name
ORDER BY violation_pct DESC;


-- Violation rate by borough
SELECT
    'Borough Breakdown'                                 AS section,
    company_name,
    pu_borough                                          AS borough,
    COUNT(*)                                            AS total_trips,
    SUM(below_tlc_minimum)                              AS violation_trips,
    ROUND(AVG(below_tlc_minimum) * 100, 2)              AS violation_pct,
    ROUND(AVG(driver_pay), 2)                           AS avg_driver_pay,
    ROUND(AVG(driver_pay_per_hour), 2)                  AS avg_driver_hourly,

    CASE
        WHEN AVG(below_tlc_minimum) * 100 >= 1.0  THEN 'HIGH RISK'
        WHEN AVG(below_tlc_minimum) * 100 >= 0.5  THEN 'MODERATE'
        WHEN AVG(below_tlc_minimum) * 100 > 0     THEN 'LOW'
        ELSE                                            'COMPLIANT'
    END                                                 AS compliance_status

FROM v_trips_enriched
WHERE below_tlc_minimum IS NOT NULL
  AND pu_borough IS NOT NULL
GROUP BY company_name, pu_borough
ORDER BY company_name, violation_pct DESC;


-- Violation rate by time of day
SELECT
    'Time of Day Breakdown'                             AS section,
    company_name,
    time_of_day,
    COUNT(*)                                            AS total_trips,
    SUM(below_tlc_minimum)                              AS violation_trips,
    ROUND(AVG(below_tlc_minimum) * 100, 2)              AS violation_pct,
    ROUND(AVG(driver_pay), 2)                           AS avg_driver_pay,
    ROUND(AVG(trip_miles), 2)                           AS avg_miles,
    ROUND(AVG(trip_min), 2)                             AS avg_trip_min

FROM v_trips_enriched
WHERE below_tlc_minimum IS NOT NULL
GROUP BY company_name, time_of_day
ORDER BY company_name, violation_pct DESC;


-- Violation rate by trip distance band
-- this is the finding that flipped my original hypothesis
SELECT
    'Short Trip Analysis'                               AS section,
    company_name,
    CASE
        WHEN trip_miles < 1   THEN 'Under 1 mile'
        WHEN trip_miles < 2   THEN '1 to 2 miles'
        WHEN trip_miles < 3   THEN '2 to 3 miles'
        WHEN trip_miles < 5   THEN '3 to 5 miles'
        ELSE                       '5 plus miles'
    END                                                 AS distance_band,

    COUNT(*)                                            AS total_trips,
    SUM(below_tlc_minimum)                              AS violation_trips,
    ROUND(AVG(below_tlc_minimum) * 100, 2)              AS violation_pct,
    ROUND(AVG(driver_pay), 2)                           AS avg_driver_pay,
    ROUND(AVG(trip_miles * 0.82 + trip_min * 0.57), 2)  AS avg_tlc_minimum_due,
    ROUND(
        AVG(CASE
            WHEN below_tlc_minimum = 1
            THEN (trip_miles * 0.82 + trip_min * 0.57) - driver_pay
        END)
    , 2)                                                AS avg_shortfall

FROM v_trips_enriched
WHERE below_tlc_minimum IS NOT NULL
GROUP BY company_name, distance_band
ORDER BY company_name,
    FIELD(distance_band,
        'Under 1 mile','1 to 2 miles','2 to 3 miles','3 to 5 miles','5 plus miles');
