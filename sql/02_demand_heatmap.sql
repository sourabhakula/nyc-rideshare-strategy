-- 02_demand_heatmap.sql
-- Sai Sourabh Akula
--
-- Borough x time of day breakdown.
-- Trying to answer: where is each platform actually winning?
-- And more importantly, where is demand high but service bad?
--
-- Part 1 gives the borough summary per platform.
-- Part 2 adds the time of day cut -- that's where it gets interesting.
-- Some boroughs look fine overall but fall apart in specific windows.
--
-- FIELD() at the end just sorts time of day in chronological order
-- instead of alphabetical. Small thing but makes the output readable.

USE nyc_rideshare;

-- Borough level: one row per borough per platform
SELECT
    'Borough Summary'                                   AS section,
    pu_borough                                          AS borough,
    company_name,

    COUNT(*)                                            AS total_trips,
    ROUND(AVG(base_passenger_fare), 2)                  AS avg_base_fare,
    ROUND(AVG(passenger_total_charge), 2)               AS avg_total_charge,
    ROUND(AVG(driver_pay), 2)                           AS avg_driver_pay,
    ROUND(
        (SUM(base_passenger_fare) - SUM(driver_pay))
        / NULLIF(SUM(base_passenger_fare), 0) * 100
    , 2)                                                AS avg_take_rate_pct,
    ROUND(AVG(trip_miles), 2)                           AS avg_miles,
    ROUND(AVG(fare_per_mile), 2)                        AS avg_fare_per_mile,
    ROUND(AVG(request_to_pickup_min), 2)                AS avg_wait_min,
    ROUND(AVG(sla_5min_met) * 100, 2)                   AS sla_5min_pct,
    ROUND(
        SUM(CASE WHEN take_rate_pct < 0 THEN 1 ELSE 0 END)
        * 100.0 / COUNT(*)
    , 2)                                                AS negative_take_rate_pct,

    RANK() OVER (
        PARTITION BY company_name
        ORDER BY COUNT(*) DESC
    )                                                   AS volume_rank_within_platform

FROM v_trips_enriched
WHERE pu_borough IS NOT NULL
GROUP BY pu_borough, company_name
ORDER BY company_name, total_trips DESC;


-- Borough x time of day: adds service status flag per segment
SELECT
    'Borough x Time'                                    AS section,
    pu_borough                                          AS borough,
    time_of_day,
    company_name,

    COUNT(*)                                            AS total_trips,
    ROUND(AVG(base_passenger_fare), 2)                  AS avg_base_fare,
    ROUND(AVG(passenger_total_charge), 2)               AS avg_total_charge,
    ROUND(AVG(driver_pay), 2)                           AS avg_driver_pay,
    ROUND(
        (SUM(base_passenger_fare) - SUM(driver_pay))
        / NULLIF(SUM(base_passenger_fare), 0) * 100
    , 2)                                                AS avg_take_rate_pct,
    ROUND(AVG(request_to_pickup_min), 2)                AS avg_wait_min,
    ROUND(AVG(sla_5min_met) * 100, 2)                   AS sla_5min_pct,

    -- below 50% SLA means half of riders wait more than 5 min. that's bad.
    CASE
        WHEN AVG(sla_5min_met) * 100 < 50 THEN 'UNDERSERVED'
        WHEN AVG(sla_5min_met) * 100 < 58 THEN 'AT RISK'
        ELSE 'ADEQUATE'
    END                                                 AS service_status

FROM v_trips_enriched
WHERE pu_borough IS NOT NULL
GROUP BY pu_borough, time_of_day, company_name
ORDER BY pu_borough, company_name,
    FIELD(time_of_day,
        'AM Rush','Midday','PM Rush','Evening','Late Night');
