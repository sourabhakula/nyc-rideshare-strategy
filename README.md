# Data Files

These CSV files feed the Power BI dashboard. They are outputs of the SQL queries run against the `nyc_rideshare` database.

The raw TLC trip data is not included in this repository due to size. Download it from the NYC Open Data portal and follow the setup instructions in the root README.

---

## Tab 2: Lyft CEO Dashboard

**tab2_borough_both_platforms.csv**  
Borough-level metrics for both Uber and Lyft. Used in the competitive grouped bar chart showing take rate and SLA side by side.  
Columns: company_name, pu_borough, trip_count, avg_base_fare, take_rate_pct, sla_5min_pct, avg_wait_min

**tab2_lyft_time_fare.csv**  
Lyft trips broken down by time of day band. Used in the time of day conditional color bar chart.  
Columns: time_of_day, trip_count, avg_base_fare, take_rate_pct, sla_5min_pct

**tab2_lyft_zones.csv**  
Lyft zone-level metrics for the zone action matrix. Filtered to zones with 50 or more trips.  
Columns: pu_zone, pu_borough, trip_count, avg_base_fare, take_rate_pct, sla_5min_pct, action_label

---

## Tab 3: TLC Commissioner Dashboard

**tab3_tlc_borough_long.csv**  
Violation rates by borough and platform in long format. Used in the enforcement bar chart.  
Columns: borough, company_name, trip_count, violation_count, violation_rate_pct, avg_shortfall_usd

**tab3_tlc_congestion.csv**  
Congestion fee burden by distance band. Used in the regressivity area chart.  
Columns: distance_band, avg_total_congestion_fee, avg_passenger_total_charge, congestion_pct_of_charge

**tab3_tlc_distance.csv**  
Violation rates by distance band and platform. Used in the violation-by-distance combo chart.  
Columns: distance_band, company_name, trip_count, violation_rate_pct, avg_driver_pay, avg_minimum_due

**tab3_tlc_enforcement_table.csv**  
Combined borough x time priority table showing both platforms. Used in the enforcement priorities table visual.  
Columns: pu_borough, time_of_day, company_name, violation_rate_pct, sla_5min_pct, avg_wait_min, priority_label

---

## Tab 4: New Entrant Dashboard

**tab4_entrant_zones.csv**  
Zone opportunity scores for the horizontal bar chart. Sorted by score descending.  
Columns: pu_zone, pu_borough, trip_count, avg_base_fare, sla_5min_pct, avg_wait_min, opportunity_score, entry_label

**tab4_wav_long.csv**  
WAV request match rates by borough in long format. Numbered borough names force sort order in Power BI.  
Columns: borough, sort_order, status, trips, match_rate_pct

**tab4_airport_paradox.csv**  
Airport zone fare and SLA data for the paradox combo chart. Gold columns for fare, red line for SLA.  
Columns: pu_zone, avg_base_fare, sla_5min_pct, trip_count, opportunity_score
