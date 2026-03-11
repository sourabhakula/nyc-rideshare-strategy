-- 08_holiday_demand_stress.sql
-- Sai Sourabh Akula
--
-- Revenue volatility through December.
--
-- December is the most analytically interesting month in this dataset
-- because you get a pre-holiday surge, a Christmas cliff, and a recovery
-- all within 31 days. I wanted to quantify how deep that cliff actually is
-- and whether the two platforms behave differently during it.
--
-- Uber peaked Dec 11 ($89k), troughed Dec 26 ($39k) -- that's a 56% drop.
-- Lyft peaked Dec 12 ($28k), troughed Dec 25 ($15k) -- 45% drop.
-- Different trough dates: Uber hits bottom Dec 26, Lyft hits bottom Dec 25.
-- That suggests different rider profiles -- Lyft riders cancel on Christmas Day
-- itself, Uber's business-ish base partially resumes Dec 26.
--
-- Window functions used here:
--   LAG()          -- previous day revenue for day-over-day % change
--   AVG() with ROWS BETWEEN 6 PRECEDING -- 7-day rolling average
--   SUM() with ROWS UNBOUNDED PRECEDING  -- cumulative month-to-date
--   RANK()         -- which day was the peak (1 = highest)

USE nyc_rideshare;

WITH daily_revenue AS (
    SELECT
        trip_date,
        company_name,
        COUNT(*)                                        AS daily_trips,
        ROUND(SUM(base_passenger_fare), 0)              AS daily_base_revenue,
        ROUND(SUM(passenger_total_charge), 0)           AS daily_total_revenue,
        ROUND(SUM(platform_spread), 0)                  AS daily_margin,
        ROUND(AVG(base_passenger_fare), 2)              AS avg_base_fare,
        ROUND(
            (SUM(base_passenger_fare) - SUM(driver_pay))
            / NULLIF(SUM(base_passenger_fare), 0) * 100
        , 2)                                            AS avg_take_rate_pct,
        ROUND(AVG(sla_5min_met) * 100, 2)               AS sla_5min_pct

    FROM v_trips_enriched
    GROUP BY trip_date, company_name
),

daily_with_lag AS (
    SELECT
        trip_date,
        company_name,
        daily_trips,
        daily_base_revenue,
        daily_total_revenue,
        daily_margin,
        avg_base_fare,
        avg_take_rate_pct,
        sla_5min_pct,

        LAG(daily_base_revenue) OVER (
            PARTITION BY company_name
            ORDER BY trip_date
        )                                               AS prev_day_revenue,

        ROUND(AVG(daily_base_revenue) OVER (
            PARTITION BY company_name
            ORDER BY trip_date
            ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
        ), 0)                                           AS rolling_7day_avg,

        SUM(daily_base_revenue) OVER (
            PARTITION BY company_name
            ORDER BY trip_date
            ROWS UNBOUNDED PRECEDING
        )                                               AS cumulative_revenue,

        RANK() OVER (
            PARTITION BY company_name
            ORDER BY daily_base_revenue DESC
        )                                               AS revenue_rank

    FROM daily_revenue
)

SELECT
    'Daily Revenue Trend'                               AS section,
    trip_date,
    company_name,
    daily_trips,
    daily_base_revenue,
    daily_total_revenue,
    daily_margin,
    avg_base_fare,
    avg_take_rate_pct,
    sla_5min_pct,
    prev_day_revenue,

    CASE
        WHEN prev_day_revenue IS NOT NULL AND prev_day_revenue > 0
        THEN ROUND(
            (daily_base_revenue - prev_day_revenue)
            / prev_day_revenue * 100
        , 1)
        ELSE NULL
    END                                                 AS dod_change_pct,

    rolling_7day_avg,
    cumulative_revenue,
    revenue_rank,

    CASE
        WHEN revenue_rank = 1                   THEN 'PEAK DAY'
        WHEN MONTH(trip_date) = 12
             AND DAY(trip_date) = 25            THEN 'CHRISTMAS TROUGH'
        WHEN MONTH(trip_date) = 12
             AND DAY(trip_date) = 26            THEN 'RECOVERY START'
        WHEN MONTH(trip_date) = 12
             AND DAY(trip_date) IN (24,31)      THEN 'HOLIDAY EVE'
        ELSE NULL
    END                                                 AS day_label

FROM daily_with_lag
ORDER BY company_name, trip_date;


-- Peak vs trough summary -- the cliff in one number per platform
WITH daily_revenue AS (
    SELECT
        trip_date,
        company_name,
        ROUND(SUM(base_passenger_fare), 0)              AS daily_base_revenue,
        COUNT(*)                                        AS daily_trips
    FROM v_trips_enriched
    GROUP BY trip_date, company_name
),
peak_trough AS (
    SELECT
        company_name,
        MAX(daily_base_revenue)                         AS peak_revenue,
        MIN(daily_base_revenue)                         AS trough_revenue,
        MAX(CASE WHEN daily_base_revenue =
            (SELECT MAX(d2.daily_base_revenue)
             FROM daily_revenue d2
             WHERE d2.company_name = daily_revenue.company_name)
            THEN trip_date END)                         AS peak_date,
        MIN(CASE WHEN daily_base_revenue =
            (SELECT MIN(d2.daily_base_revenue)
             FROM daily_revenue d2
             WHERE d2.company_name = daily_revenue.company_name)
            THEN trip_date END)                         AS trough_date
    FROM daily_revenue
    GROUP BY company_name
)
SELECT
    'Peak vs Trough'                                    AS section,
    company_name,
    peak_date,
    peak_revenue,
    trough_date,
    trough_revenue,
    ROUND((trough_revenue - peak_revenue)
          / peak_revenue * 100, 1)                      AS cliff_pct,
    ROUND(peak_revenue / NULLIF(trough_revenue, 0), 2)  AS peak_to_trough_ratio
FROM peak_trough
ORDER BY company_name;
