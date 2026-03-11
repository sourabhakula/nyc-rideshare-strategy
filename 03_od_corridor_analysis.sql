-- 03_od_corridor_analysis.sql
-- Sai Sourabh Akula
--
-- Where does the money actually flow? Which pickup-dropoff pairs
-- are the most valuable, and how do airport routes compare to everything else?
--
-- Three parts:
--   Part 1: top 20 zone-level corridors by trip volume
--   Part 2: airport vs non-airport split (this is where the pricing story gets interesting)
--   Part 3: borough-to-borough matrix -- the big picture view
--
-- Minimum 50 trips per corridor for Part 1.
-- Below that, the averages aren't reliable enough to mean anything.
--
-- airport_fee > 0 is the right proxy for airport trips.
-- There's no dedicated airport flag in the raw data -- I validated this
-- by cross-checking with zone names and it holds up cleanly.

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


-- Airport vs non-airport comparison
-- The fare gap here is one of the biggest findings in the whole project
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


-- Borough-to-borough revenue flow matrix
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
