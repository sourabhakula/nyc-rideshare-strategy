-- 07_congestion_burden_analysis.sql
-- Sai Sourabh Akula
--
-- Congestion fee analysis. This is central to the whole project --
-- it's literally in the title.
--
-- Two separate fees in the data:
--   congestion_surcharge  = state fee, exists since 2019, trips in/through
--                           Manhattan below 96th St
--   cbd_congestion_fee    = new MTA Central Business District fee,
--                           effective Jan 5 2025, trips into Manhattan
--                           below 60th St
--
-- I kept them separate in the view because they have different legal
-- histories and footprints. Combined them here for the burden calc
-- since what matters for equity analysis is the total rider impact.
--
-- The main finding: the regressivity isn't geographic, it's by trip length.
-- Outer boroughs have low burden because their trips don't touch the zones.
-- Manhattan bears ~85% of total congestion fee incidence -- but that's
-- geographic alignment, not unfair targeting.
-- The unfairness is: sub-1-mile trips pay 8-9% of their fare in flat fees.
-- 10+ mile trips pay about 2%. A flat fee on a $10 ride hits different
-- than a flat fee on an $80 airport run.

USE nyc_rideshare;

-- Congestion burden by borough
SELECT
    'Borough Congestion Burden'                         AS section,
    pu_borough                                          AS borough,
    company_name,
    COUNT(*)                                            AS total_trips,

    ROUND(AVG(base_passenger_fare), 2)                  AS avg_base_fare,
    ROUND(AVG(passenger_total_charge), 2)               AS avg_total_charge,
    ROUND(AVG(congestion_surcharge), 2)                 AS avg_congestion_surcharge,
    ROUND(AVG(cbd_congestion_fee), 2)                   AS avg_cbd_fee,
    ROUND(AVG(total_congestion_fees), 2)                AS avg_total_congestion,

    ROUND(
        AVG(total_congestion_fees)
        / NULLIF(AVG(passenger_total_charge), 0) * 100
    , 1)                                                AS congestion_burden_pct,

    ROUND(
        AVG(total_congestion_fees)
        / NULLIF(AVG(base_passenger_fare), 0) * 100
    , 1)                                                AS congestion_vs_base_pct,

    ROUND(
        SUM(CASE WHEN total_congestion_fees > 0 THEN 1 ELSE 0 END)
        * 100.0 / COUNT(*)
    , 1)                                                AS trips_with_congestion_pct,

    CASE
        WHEN AVG(total_congestion_fees)
             / NULLIF(AVG(passenger_total_charge), 0) * 100 >= 10
        THEN 'HIGH BURDEN'
        WHEN AVG(total_congestion_fees)
             / NULLIF(AVG(passenger_total_charge), 0) * 100 >= 5
        THEN 'MODERATE BURDEN'
        ELSE 'LOW BURDEN'
    END                                                 AS equity_status

FROM v_trips_enriched
WHERE pu_borough IS NOT NULL
GROUP BY pu_borough, company_name
ORDER BY congestion_burden_pct DESC;


-- Burden by trip distance -- this is where the regressivity actually shows up
SELECT
    'Distance Band Burden'                              AS section,
    company_name,
    CASE
        WHEN trip_miles < 1  THEN 'Under 1 mile'
        WHEN trip_miles < 2  THEN '1 to 2 miles'
        WHEN trip_miles < 3  THEN '2 to 3 miles'
        WHEN trip_miles < 5  THEN '3 to 5 miles'
        WHEN trip_miles < 10 THEN '5 to 10 miles'
        ELSE                      '10 plus miles'
    END                                                 AS distance_band,

    COUNT(*)                                            AS total_trips,
    ROUND(AVG(base_passenger_fare), 2)                  AS avg_base_fare,
    ROUND(AVG(total_congestion_fees), 2)                AS avg_congestion_fees,
    ROUND(
        AVG(total_congestion_fees)
        / NULLIF(AVG(passenger_total_charge), 0) * 100
    , 1)                                                AS congestion_burden_pct

FROM v_trips_enriched
GROUP BY company_name, distance_band
ORDER BY company_name,
    FIELD(distance_band,
        'Under 1 mile','1 to 2 miles','2 to 3 miles',
        '3 to 5 miles','5 to 10 miles','10 plus miles');


-- Which specific zones are generating the most CBD fees?
SELECT
    'CBD Zone Footprint'                                AS section,
    pu_borough                                          AS borough,
    pu_zone                                             AS zone,
    COUNT(*)                                            AS total_trips,
    ROUND(AVG(cbd_congestion_fee), 2)                   AS avg_cbd_fee,
    ROUND(SUM(cbd_congestion_fee), 0)                   AS total_cbd_fees_collected,
    ROUND(
        SUM(CASE WHEN cbd_congestion_fee > 0 THEN 1 ELSE 0 END)
        * 100.0 / COUNT(*)
    , 1)                                                AS trips_with_cbd_fee_pct

FROM v_trips_enriched
WHERE pu_borough IS NOT NULL
GROUP BY pu_borough, pu_zone
HAVING AVG(cbd_congestion_fee) > 0
ORDER BY total_cbd_fees_collected DESC
LIMIT 20;
