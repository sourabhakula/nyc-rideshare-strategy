-- 05_passenger_price_decomposition.sql
-- Sai Sourabh Akula
--
-- Breaking down where every rider dollar actually goes.
--
-- The total charge a rider pays = base fare + tolls + BCF + sales tax
-- + congestion surcharge + CBD fee + airport fee + tips.
-- I wanted to know what percentage each piece represents.
--
-- Part 3 is the one that surprised me most: the airport_fee (the
-- government-mandated surcharge) is only 5-7% of the airport price premium.
-- The other 93-95% is just platform pricing. Riders at JFK are paying
-- almost $90 more than a regular trip and almost none of that is regulated.
--
-- Part 2 tests whether the flat congestion fees are regressive.
-- Spoiler: not really by borough, but very much by trip distance.
-- Short trips inside Manhattan pay 8-9% of their fare in flat fees.
-- Long airport runs pay about 2%. That gap is what matters for equity.

USE nyc_rideshare;

-- Full fee breakdown per platform
SELECT
    'Platform Decomposition'                            AS section,
    company_name,
    COUNT(*)                                            AS total_trips,

    ROUND(AVG(base_passenger_fare), 2)                  AS avg_base_fare,
    ROUND(AVG(tolls), 2)                                AS avg_tolls,
    ROUND(AVG(bcf), 2)                                  AS avg_bcf,
    ROUND(AVG(sales_tax), 2)                            AS avg_sales_tax,
    ROUND(AVG(congestion_surcharge), 2)                 AS avg_congestion_surcharge,
    ROUND(AVG(cbd_congestion_fee), 2)                   AS avg_cbd_fee,
    ROUND(AVG(airport_fee), 2)                          AS avg_airport_fee,
    ROUND(AVG(tips), 2)                                 AS avg_tips,
    ROUND(AVG(passenger_total_charge), 2)               AS avg_total_charge,

    ROUND(AVG(base_passenger_fare)
          / NULLIF(AVG(passenger_total_charge), 0) * 100, 1)
                                                        AS base_pct_of_total,
    ROUND(AVG(congestion_surcharge)
          / NULLIF(AVG(passenger_total_charge), 0) * 100, 1)
                                                        AS congestion_pct_of_total,
    ROUND(AVG(cbd_congestion_fee)
          / NULLIF(AVG(passenger_total_charge), 0) * 100, 1)
                                                        AS cbd_pct_of_total,
    ROUND(
        (AVG(congestion_surcharge) + AVG(cbd_congestion_fee))
        / NULLIF(AVG(passenger_total_charge), 0) * 100, 1)
                                                        AS total_congestion_pct,
    ROUND(AVG(sales_tax)
          / NULLIF(AVG(passenger_total_charge), 0) * 100, 1)
                                                        AS tax_pct_of_total,
    ROUND(AVG(tips)
          / NULLIF(AVG(passenger_total_charge), 0) * 100, 1)
                                                        AS tips_pct_of_total,
    ROUND(AVG(driver_pay)
          / NULLIF(AVG(passenger_total_charge), 0) * 100, 1)
                                                        AS driver_pct_of_total,
    ROUND(AVG(platform_spread)
          / NULLIF(AVG(passenger_total_charge), 0) * 100, 1)
                                                        AS platform_pct_of_total

FROM v_trips_enriched
GROUP BY company_name
ORDER BY company_name;


-- Congestion fee burden by borough
-- testing whether outer borough riders pay a higher share in flat fees
SELECT
    'Borough Fee Burden'                                AS section,
    pu_borough                                          AS borough,
    company_name,
    COUNT(*)                                            AS total_trips,

    ROUND(AVG(base_passenger_fare), 2)                  AS avg_base_fare,
    ROUND(AVG(passenger_total_charge), 2)               AS avg_total_charge,
    ROUND(AVG(total_congestion_fees), 2)                AS avg_congestion_fees,

    ROUND(
        AVG(total_congestion_fees)
        / NULLIF(AVG(passenger_total_charge), 0) * 100
    , 1)                                                AS congestion_burden_pct,

    ROUND(AVG(tips), 2)                                 AS avg_tips,
    ROUND(AVG(driver_pay), 2)                           AS avg_driver_pay

FROM v_trips_enriched
WHERE pu_borough IS NOT NULL
GROUP BY pu_borough, company_name
ORDER BY pu_borough, company_name;


-- Airport fee as % of total airport charge
-- how much of the airport premium is actually the regulated fee vs platform markup?
SELECT
    'Airport Fee Structure'                             AS section,
    company_name,
    CASE WHEN is_airport_trip = 1 THEN 'Airport' ELSE 'Non-Airport' END
                                                        AS trip_type,
    COUNT(*)                                            AS total_trips,
    ROUND(AVG(base_passenger_fare), 2)                  AS avg_base_fare,
    ROUND(AVG(airport_fee), 2)                          AS avg_airport_fee,
    ROUND(AVG(passenger_total_charge), 2)               AS avg_total_charge,
    ROUND(AVG(airport_fee)
          / NULLIF(AVG(passenger_total_charge), 0) * 100, 1)
                                                        AS airport_fee_pct_of_total,
    ROUND(
        (SUM(base_passenger_fare) - SUM(driver_pay))
        / NULLIF(SUM(base_passenger_fare), 0) * 100
    , 2)                                                AS take_rate_pct

FROM v_trips_enriched
GROUP BY company_name, is_airport_trip
ORDER BY company_name, is_airport_trip DESC;
