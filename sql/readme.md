# SQL

12 queries built in MySQL against the NYC TLC trip dataset (December 2025, ~100K rows).

## Files

**00_setup_view.sql**
Creates v_trips_enriched — the base view everything else depends on. Run this first. Contains all derived columns: wait time, SLA flag, take rate, TLC minimum pay check, fare components, and zone joins.

**01_market_position.sql**
Full platform scorecard. One row per platform across 20 KPIs — volume, fares, driver pay, take rate, SLA, wait time, and compliance.

**02_demand_heatmap.sql**
Borough x time of day breakdown. Identifies where each platform is winning and where demand is high but service quality is poor.

**03_od_corridor_analysis.sql**
Origin-destination corridor analysis. Top 20 zone-level corridors by volume, airport vs non-airport economics, and borough-to-borough revenue matrix.

**04_take_rate_fare_decile.sql**
Margin breakdown by fare decile using NTILE(10). Diagnoses where platform margin is healthy vs bleeding across the fare spectrum.

**05_passenger_price_decomposition.sql**
Full fee breakdown per rider — base fare, tolls, BCF, sales tax, congestion surcharge, CBD fee, airport fee, tips. Tests whether flat fees create a regressive burden on short-trip riders.

**06_driver_pay_stress_test.sql**
TLC minimum pay compliance check ($0.82/mile + $0.57/min). Violation rate by platform, borough, time of day, and trip distance.

**07_congestion_burden_analysis.sql**
Congestion fee analysis by borough and trip distance. Quantifies how the flat-fee structure falls harder on short cheap trips than long airport runs.

**08_holiday_demand_stress.sql**
Daily revenue trend through December using LAG, rolling 7-day average, and cumulative window functions. Measures the Christmas demand cliff for each platform.

**09_price_volatility.sql**
Fare variance by zone using coefficient of variation. Identifies stable vs volatile markets and flags zones where a new entrant could predict pricing reliably.

**10_zone_opportunity_matrix.sql**
Composite opportunity score per zone (volume 30%, fare 25%, SLA gap 30%, wait gap 15%). Identifies the strongest entry targets for a new market entrant.

**11_growth_quality_score.sql**
Closing analysis. Scores every platform x borough x time segment across 4 dimensions — margin health, service quality, driver compliance, price stability — and returns a strategic verdict per segment.
