-- 00_setup_view.sql
-- Sai Sourabh Akula
--
-- Run this first. All downstream queries depend on this view.
-- Derived columns (fare totals, wait time, SLA, TLC min pay) live here
-- so the logic only gets written once.
--

--   trip_time is in SECONDS. Divided by 60 everywhere.
--   originating_base_num is NULL on every row. Left it out.
--   Wait time filter: negative or >7200s rows are bad data.
--   HV0003 = Uber, HV0005 = Lyft (TLC license registry).

USE nyc_rideshare;

DROP VIEW IF EXISTS v_trips_enriched;

CREATE VIEW v_trips_enriched AS
SELECT

    t.hvfhs_license_num,
    CASE
        WHEN t.hvfhs_license_num = 'HV0003' THEN 'Uber'
        WHEN t.hvfhs_license_num = 'HV0005' THEN 'Lyft'
        ELSE 'Other'
    END                                                     AS company_name,

    t.request_datetime,
    t.on_scene_datetime,
    t.pickup_datetime,
    t.dropoff_datetime,
    DATE(t.pickup_datetime)                                 AS trip_date,

    -- aligned with MTA peak/off-peak windows
    CASE
        WHEN HOUR(t.pickup_datetime) BETWEEN 6  AND 9  THEN 'AM Rush'
        WHEN HOUR(t.pickup_datetime) BETWEEN 10 AND 15 THEN 'Midday'
        WHEN HOUR(t.pickup_datetime) BETWEEN 16 AND 19 THEN 'PM Rush'
        WHEN HOUR(t.pickup_datetime) BETWEEN 20 AND 22 THEN 'Evening'
        ELSE                                                 'Late Night'
    END                                                     AS time_of_day,

    -- zone lookup joined twice: pickup and dropoff
    t.PULocationID,
    t.DOLocationID,
    pu.Borough                                              AS pu_borough,
    pu.Zone                                                 AS pu_zone,
    pu.service_zone                                         AS pu_service_zone,
    do_.Borough                                             AS do_borough,
    do_.Zone                                                AS do_zone,
    do_.service_zone                                        AS do_service_zone,

    t.trip_miles,
    ROUND(t.trip_time / 60.0, 2)                            AS trip_min,

    -- rider wait: request to actual pickup
    ROUND(
        TIMESTAMPDIFF(SECOND, t.request_datetime, t.pickup_datetime)
        / 60.0
    , 2)                                                    AS request_to_pickup_min,

    -- 0/1 so AVG() gives the rate directly
    CASE
        WHEN TIMESTAMPDIFF(SECOND, t.request_datetime, t.pickup_datetime)
             <= 300 THEN 1
        ELSE 0
    END                                                     AS sla_5min_met,

    t.base_passenger_fare,
    COALESCE(t.tolls, 0)                                    AS tolls,
    COALESCE(t.bcf, 0)                                      AS bcf,
    COALESCE(t.sales_tax, 0)                                AS sales_tax,
    COALESCE(t.congestion_surcharge, 0)                     AS congestion_surcharge,
    COALESCE(t.airport_fee, 0)                              AS airport_fee,
    COALESCE(t.cbd_congestion_fee, 0)                       AS cbd_congestion_fee,
    COALESCE(t.tips, 0)                                     AS tips,
    t.driver_pay,

    -- total rider out-of-pocket
    ROUND(
        t.base_passenger_fare
        + COALESCE(t.tolls, 0)
        + COALESCE(t.bcf, 0)
        + COALESCE(t.sales_tax, 0)
        + COALESCE(t.congestion_surcharge, 0)
        + COALESCE(t.airport_fee, 0)
        + COALESCE(t.cbd_congestion_fee, 0)
        + COALESCE(t.tips, 0)
    , 2)                                                    AS passenger_total_charge,

    -- both congestion fees combined for burden analysis
    ROUND(
        COALESCE(t.congestion_surcharge, 0)
        + COALESCE(t.cbd_congestion_fee, 0)
    , 2)                                                    AS total_congestion_fees,

    -- platform keep per trip (negative = platform loses money)
    ROUND(t.base_passenger_fare - t.driver_pay, 2)          AS platform_spread,

    -- per-trip take rate, only for decile work and counting negatives
    -- do NOT AVG this across segments; use SUM-based calc instead
    CASE
        WHEN t.base_passenger_fare > 0
        THEN ROUND(
            (t.base_passenger_fare - t.driver_pay)
            / t.base_passenger_fare * 100
        , 2)
        ELSE NULL
    END                                                     AS take_rate_pct,

    CASE
        WHEN t.trip_miles > 0
        THEN ROUND(t.base_passenger_fare / t.trip_miles, 2)
        ELSE NULL
    END                                                     AS fare_per_mile,

    CASE
        WHEN t.trip_time > 0
        THEN ROUND(t.driver_pay / t.trip_time * 3600, 2)
        ELSE NULL
    END                                                     AS driver_pay_per_hour,

    -- TLC minimum pay: $0.82/mile + $0.57/min. flag=1 means underpaid.
    CASE
        WHEN t.trip_miles > 0 AND t.trip_time > 0
        THEN CASE
            WHEN t.driver_pay <
                 ROUND(
                     (t.trip_miles * 0.82)
                     + (t.trip_time / 60.0 * 0.57)
                 , 2)
            THEN 1 ELSE 0
        END
        ELSE NULL
    END                                                     AS below_tlc_minimum,

    -- airport_fee > 0 is the best proxy (validated against zone names)
    CASE
        WHEN t.airport_fee > 0 THEN 1
        ELSE 0
    END                                                     AS is_airport_trip,

    t.shared_request_flag,
    t.shared_match_flag,
    t.access_a_ride_flag,
    t.wav_request_flag,
    t.wav_match_flag

FROM trips t
LEFT JOIN taxi_zone_lookup pu  ON t.PULocationID = pu.LocationID
LEFT JOIN taxi_zone_lookup do_ ON t.DOLocationID = do_.LocationID

WHERE
    t.pickup_datetime       IS NOT NULL
    AND t.dropoff_datetime  IS NOT NULL
    AND t.request_datetime  IS NOT NULL
    AND t.base_passenger_fare IS NOT NULL
    AND t.driver_pay        IS NOT NULL
    AND t.trip_miles        > 0
    AND t.trip_time         > 0
    AND TIMESTAMPDIFF(SECOND, t.request_datetime, t.pickup_datetime)
        BETWEEN 0 AND 7200
    AND t.hvfhs_license_num IN ('HV0003', 'HV0005');
