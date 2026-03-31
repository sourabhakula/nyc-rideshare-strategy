-- 03_od_corridor_analysis.sql
-- Sai Sourabh Akula
--
-- Which pickup-dropoff pairs carry the most volume and revenue?
-- How do airport routes compare to everything else?
--
-- Part 1: top 20 zone-level corridors (min 50 trips per corridor)
-- Part 2: airport vs non-airport split
-- Part 3: borough-to-borough flow matrix
--
-- airport_fee > 0 is the proxy for airport trips. No dedicated flag
-- in the raw data; validated by cross-checking zone names.

USE nyc_rideshare;

-- Top 20 origin-destination pairs by volume
SELECT
    'Top Corridors'                                     AS section,
    pu_borough                                          AS origin_borough,
    pu_zone                                             AS origin_zone,
    do_borough                                          AS dest_borough,
    do_zone                                             AS dest_zone,
    CONCAT(pu_borough, ' to ', do_borough)              AS corridor,

    COUNT(*)                                            AS total_trips,
    ROUND(AVG(base_passenger_fare), 2)                  AS avg_base_fare,
    ROUND(AVG(passenger_total_charge), 2)               AS avg_total_charge,
    ROUND(AVG(driver_pay), 2)                           AS avg_driver_pay,
    ROUND(
        (SUM(base_passenger_fare) - SUM(driver_pay))
        / NULLIF(SUM(base_passenger_fare), 0) * 100
    , 2)                                                AS take_rate_pct,
    ROUND(AVG(trip_miles), 2)                           AS avg_miles,
    ROUND(AVG(fare_per_mile), 2)                        AS avg_fare_per_mile,
    ROUND(AVG(sla_5min_met) * 100, 2)                   AS sla_5min_pct,
    ROUND(AVG(request_to_pickup_min), 2)                AS avg_wait_min,
    ROUND(SUM(base_passenger_fare), 0)                  AS total_base_revenue

FROM v_trips_enriched
WHERE
    pu_borough  IS NOT NULL
    AND do_borough  IS NOT NULL
GROUP BY
    pu_borough, pu_zone, do_borough, do_zone
HAVING COUNT(*) >= 50
ORDER BY total_trips DESC
LIMIT 20;


-- Airport vs non-airport
SELECT
    'Airport Segment'                                   AS section,
    company_name,
    CASE
        WHEN is_airport_trip = 1 THEN 'Airport'
        ELSE 'Non-Airport'
    END                                                 AS trip_type,

    COUNT(*)                                            AS total_trips,
    ROUND(AVG(base_passenger_fare), 2)                  AS avg_base_fare,
    ROUND(AVG(passenger_total_charge), 2)               AS avg_total_charge,
    ROUND(AVG(driver_pay), 2)                           AS avg_driver_pay,
    ROUND(
        (SUM(base_passenger_fare) - SUM(driver_pay))
        / NULLIF(SUM(base_passenger_fare), 0) * 100
    , 2)                                                AS take_rate_pct,
    ROUND(AVG(trip_miles), 2)                           AS avg_miles,
    ROUND(AVG(fare_per_mile), 2)                        AS avg_fare_per_mile,
    ROUND(AVG(sla_5min_met) * 100, 2)                   AS sla_5min_pct,
    ROUND(AVG(request_to_pickup_min), 2)                AS avg_wait_min

FROM v_trips_enriched
GROUP BY company_name, is_airport_trip
ORDER BY company_name, is_airport_trip DESC;


-- Borough-to-borough revenue flow
SELECT
    'Borough Matrix'                                    AS section,
    pu_borough                                          AS origin,
    do_borough                                          AS destination,

    COUNT(*)                                            AS total_trips,
    ROUND(AVG(base_passenger_fare), 2)                  AS avg_base_fare,
    ROUND(AVG(fare_per_mile), 2)                        AS avg_fare_per_mile,
    ROUND(
        (SUM(base_passenger_fare) - SUM(driver_pay))
        / NULLIF(SUM(base_passenger_fare), 0) * 100
    , 2)                                                AS take_rate_pct,
    ROUND(AVG(sla_5min_met) * 100, 2)                   AS sla_5min_pct,
    ROUND(SUM(base_passenger_fare), 0)                  AS total_revenue

FROM v_trips_enriched
WHERE pu_borough IS NOT NULL AND do_borough IS NOT NULL
GROUP BY pu_borough, do_borough
ORDER BY total_trips DESC
LIMIT 25;
