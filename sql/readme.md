# SQL

12 queries built in MySQL against the NYC TLC trip dataset, December 2025, 
roughly 100,000 trips after cleaning.

run 00_setup_view.sql first. it creates v_trips_enriched which is the base 
view everything else depends on. it builds all the derived columns in one place, 
wait time, SLA flag, take rate, TLC minimum pay check, fare components, zone 
joins. every other query just selects from that view.

01_market_position.sql is the platform scorecard. one row per platform, 20 KPIs 
across volume, fares, driver pay, take rate, SLA, wait time and compliance. 
good starting point if you want to see the full picture before digging in.

02_demand_heatmap.sql breaks things down by borough and time of day. where each 
platform is winning, where demand is high but service quality is poor.

03_od_corridor_analysis.sql looks at origin to destination pairs. top 20 zone 
level corridors by volume, airport versus non-airport economics, borough to 
borough revenue matrix.

04_take_rate_fare_decile.sql is where the margin story gets interesting. uses 
NTILE(10) to split trips into fare deciles and shows where platform margin is 
healthy versus bleeding. the finding here is that the problem is in the middle 
of the distribution, not the bottom.

05_passenger_price_decomposition.sql breaks down exactly what riders are paying 
and why. base fare, tolls, black car fund, sales tax, congestion surcharge, CBD 
fee, airport fee, tips. tests whether the flat fee structure creates a regressive 
burden on short trip riders.

06_driver_pay_stress_test.sql runs a TLC minimum pay compliance check against 
the $0.82 per mile and $0.57 per minute formula. violation rate by platform, 
borough, time of day and trip distance. this is where the 150x gap between Uber 
and Lyft violations shows up.

07_congestion_burden_analysis.sql quantifies how the flat congestion fee falls 
harder on short cheap trips than long airport runs. the 8.9% versus 1.9% finding 
comes out of this one.

08_holiday_demand_stress.sql uses LAG and rolling window functions to track the 
daily revenue trend through December. measures the Christmas demand cliff for 
each platform.

09_price_volatility.sql calculates coefficient of variation by zone. identifies 
stable versus volatile markets and flags zones where a new entrant could reliably 
predict what riders will pay.

10_zone_opportunity_matrix.sql builds the composite opportunity score per zone. 
weighted across volume, fare level, SLA gap and wait gap. this is what identifies 
LaGuardia and JFK as the only two strong entry targets in the dataset.

11_growth_quality_score.sql is the closing analysis. scores every platform by 
borough by time segment across margin health, service quality, driver compliance 
and price stability. returns a strategic verdict per segment. Uber Staten Island 
late night is the worst case in the whole dataset.
