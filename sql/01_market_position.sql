-- 01_market_position.sql
-- Sai Sourabh Akula
--
-- Platform scorecard. I run this first every time -- it sets
-- the baseline numbers that everything else gets compared against.
--
-- One row per platform, about 20 KPIs: volume, fares, driver pay,
-- take rate, SLA, wait time, compliance.
--
-- Take rate note: using SUM-based aggregate method here, not AVG of
-- per-trip rates. Averaging individual rates gives a distorted number
-- when there are outliers. The correct approach is:
--   (total base fare collected - total driver pay) / total base fare
-- Tested both methods on Uber Bronx -- SUM gave 11.01%, AVG gave 14.21%.
-- That 3-point gap changes how you read the whole margin story.

USE nyc_rideshare;

SELECT
    company_name,

    COUNT(*)                                            AS total_trips,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2) AS market_share_pct,

    ROUND(AVG(base_passenger_fare), 2)                  AS avg_base_fare,
    ROUND(AVG(passenger_total_charge), 2)               AS avg_total_charge,

    ROUND(AVG(driver_pay), 2)                           AS avg_driver_pay,
    ROUND(AVG(tips), 2)                                 AS avg_tip,
    ROUND(AVG(driver_pay_per_hour), 2)                  AS avg_driver_hourly,

    ROUND(
        (SUM(base_passenger_fare) - SUM(driver_pay))
        / NULLIF(SUM(base_passenger_fare), 0) * 100
    , 2)                                                AS avg_take_rate_pct,
    ROUND(AVG(platform_spread), 2)                      AS avg_platform_spread,

    -- how many trips are actually costing the platform money
    ROUND(
        SUM(CASE WHEN take_rate_pct < 0 THEN 1 ELSE 0 END)
        * 100.0 / COUNT(*)
    , 2)                                                AS negative_take_rate_pct,

    ROUND(AVG(trip_miles), 2)                           AS avg_trip_miles,
    ROUND(AVG(trip_min), 2)                             AS avg_trip_min,
    ROUND(AVG(fare_per_mile), 2)                        AS avg_fare_per_mile,

    ROUND(AVG(request_to_pickup_min), 2)                AS avg_wait_min,
    ROUND(AVG(sla_5min_met) * 100, 2)                   AS sla_5min_pct,

    -- using 1.0/0.0 to avoid integer division rounding in MySQL
    ROUND(
        AVG(CASE WHEN below_tlc_minimum = 1 THEN 1.0 ELSE 0.0 END) * 100
    , 2)                                                AS below_tlc_min_pct,

    ROUND(SUM(base_passenger_fare), 0)                  AS total_base_revenue,
    ROUND(SUM(passenger_total_charge), 0)               AS total_charge_revenue,
    ROUND(SUM(platform_spread), 0)                      AS total_platform_margin

FROM v_trips_enriched
GROUP BY company_name
ORDER BY total_trips DESC;
