-- 10_zone_opportunity_matrix.sql
-- Sai Sourabh Akula
--
-- If I were advising a new platform entering NYC, which zones would I tell
-- them to look at first?
--
-- Built a composite score across 4 dimensions:
--   Volume (30%)  -- is there enough demand to build on?
--   Fare (25%)    -- does the unit economics work?
--   SLA gap (30%) -- is the incumbent actually failing riders here?
--   Wait gap (15%) -- secondary confirmation of supply shortage
--
-- Min-max normalized so a dollar metric and a percentage metric can
-- combine without one dimension dominating just from scale.
-- SLA and wait are inverted -- lower incumbent SLA = higher opportunity score.
--
-- LaGuardia scored 100. JFK scored 78.6. Both airports are in a different
-- tier from everything else. 41-minute average wait at LaGuardia on a $63
-- average fare. Riders paying 3x the city average for the worst service.
--
-- WAV gap analysis is in Part 2. Requests exist but go unmatched in the
-- Bronx and Manhattan. That's a fulfillment failure, not suppressed demand.
-- A new entrant with a dedicated WAV fleet has a real moat there.

USE nyc_rideshare;

WITH zone_metrics AS (
    SELECT
        pu_borough                                      AS borough,
        pu_zone                                         AS zone,
        COUNT(*)                                        AS total_trips,
        ROUND(AVG(base_passenger_fare), 2)              AS avg_base_fare,
        ROUND(AVG(passenger_total_charge), 2)           AS avg_total_charge,
        ROUND(
            (SUM(base_passenger_fare) - SUM(driver_pay))
            / NULLIF(SUM(base_passenger_fare), 0) * 100
        , 2)                                            AS avg_take_rate_pct,
        ROUND(AVG(sla_5min_met) * 100, 2)               AS sla_pct,
        ROUND(AVG(request_to_pickup_min), 2)            AS avg_wait_min,
        ROUND(AVG(below_tlc_minimum) * 100, 2)          AS violation_pct,
        ROUND(STDDEV(base_passenger_fare), 2)           AS fare_stddev,

        SUM(CASE WHEN wav_request_flag = 'Y' THEN 1 ELSE 0 END)
                                                        AS wav_requests,
        SUM(CASE WHEN wav_match_flag = 'Y' THEN 1 ELSE 0 END)
                                                        AS wav_matches,
        SUM(CASE WHEN shared_request_flag = 'Y' THEN 1 ELSE 0 END)
                                                        AS shared_requests

    FROM v_trips_enriched
    WHERE pu_zone IS NOT NULL
      AND below_tlc_minimum IS NOT NULL
    GROUP BY pu_borough, pu_zone
    HAVING COUNT(*) >= 50
),

normalized AS (
    SELECT
        borough,
        zone,
        total_trips,
        avg_base_fare,
        avg_total_charge,
        avg_take_rate_pct,
        sla_pct,
        avg_wait_min,
        violation_pct,
        fare_stddev,
        wav_requests,
        wav_matches,
        shared_requests,

        ROUND(
            (total_trips - MIN(total_trips) OVER ())
            / NULLIF(MAX(total_trips) OVER () - MIN(total_trips) OVER (), 0)
            * 100
        , 1)                                            AS volume_score,

        ROUND(
            (avg_base_fare - MIN(avg_base_fare) OVER ())
            / NULLIF(MAX(avg_base_fare) OVER () - MIN(avg_base_fare) OVER (), 0)
            * 100
        , 1)                                            AS fare_score,

        -- inverted: lower incumbent SLA = bigger opportunity
        ROUND(
            (MAX(sla_pct) OVER () - sla_pct)
            / NULLIF(MAX(sla_pct) OVER () - MIN(sla_pct) OVER (), 0)
            * 100
        , 1)                                            AS sla_gap_score,

        -- inverted: longer wait = more opportunity
        ROUND(
            (avg_wait_min - MIN(avg_wait_min) OVER ())
            / NULLIF(MAX(avg_wait_min) OVER () - MIN(avg_wait_min) OVER (), 0)
            * 100
        , 1)                                            AS wait_gap_score

    FROM zone_metrics
),

scored AS (
    SELECT
        *,
        ROUND(
            (volume_score  * 0.30)
          + (fare_score    * 0.25)
          + (sla_gap_score * 0.30)
          + (wait_gap_score* 0.15)
        , 1)                                            AS opportunity_score

    FROM normalized
)

-- Top 30 opportunity zones
SELECT
    'Opportunity Matrix'                                AS section,
    borough,
    zone,
    total_trips,
    avg_base_fare,
    avg_total_charge,
    avg_take_rate_pct,
    sla_pct,
    avg_wait_min,
    violation_pct,
    volume_score,
    fare_score,
    sla_gap_score,
    wait_gap_score,
    opportunity_score,

    RANK() OVER (ORDER BY opportunity_score DESC)       AS opportunity_rank,

    CASE
        WHEN opportunity_score >= 60 THEN 'STRONG ENTRY TARGET'
        WHEN opportunity_score >= 40 THEN 'MONITOR'
        ELSE                              'INCUMBENT DEFENDED'
    END                                                 AS entry_recommendation,

    CASE
        WHEN wav_requests > 0 AND wav_matches = 0 THEN 'WAV DEMAND UNMET'
        WHEN wav_requests = 0                     THEN 'WAV SUPPRESSED'
        ELSE                                           'WAV SERVED'
    END                                                 AS wav_status

FROM scored
ORDER BY opportunity_score DESC
LIMIT 30;


-- WAV accessibility gap by borough
SELECT
    'WAV Gap Analysis'                                  AS section,
    pu_borough                                          AS borough,
    COUNT(*)                                            AS total_trips,
    SUM(CASE WHEN wav_request_flag = 'Y' THEN 1 ELSE 0 END)
                                                        AS wav_requests,
    SUM(CASE WHEN wav_match_flag   = 'Y' THEN 1 ELSE 0 END)
                                                        AS wav_matches,
    ROUND(
        SUM(CASE WHEN wav_request_flag = 'Y' THEN 1 ELSE 0 END)
        * 100.0 / COUNT(*)
    , 3)                                                AS wav_request_rate_pct,

    -- zero requests often means suppressed demand, not absence of need
    CASE
        WHEN SUM(CASE WHEN wav_request_flag = 'Y' THEN 1 ELSE 0 END) = 0
        THEN 'SUPPRESSED DEMAND -- accessibility gap likely'
        WHEN SUM(CASE WHEN wav_match_flag = 'Y' THEN 1 ELSE 0 END) = 0
        THEN 'REQUESTS UNMET -- fulfillment failure'
        ELSE 'PARTIALLY SERVED'
    END                                                 AS wav_interpretation

FROM v_trips_enriched
WHERE pu_borough IS NOT NULL
GROUP BY pu_borough
ORDER BY wav_requests DESC;
