-- TLC minimum pay compliance check
-- Sai Sourabh Akula
--
-- Formula: $0.82/mile + $0.57/min. below_tlc_minimum flag set in the view.
--
-- Uber: 1.05% violation rate (750 trips). Lyft: 0.02% (5 trips).
-- 52:1 ratio not explained by volume alone (Uber does 2.6x more trips).
--
-- Violations are worst on long trips, not short ones. The time component
-- drives it: a 60-min trip in traffic racks up $34+ in minimum pay from
-- time alone. If the fare was locked before traffic hit, it can't cover that.
--
-- Avg shortfall per Uber violation: $5.11. ~$3,832/month total.
-- Small but completely preventable.

USE nyc_rideshare;

-- Platform-level overview
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


-- By borough
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


-- By time of day
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


-- By distance band (flipped my original hypothesis)
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
