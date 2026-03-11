# Profitable Growth Under Congestion Constraints
### A SQL and Business Intelligence Strategy Case Study for NYC Ride-Hailing

**Sai Sourabh Akula** — Business Data Analyst  
MySQL 8.0 · Power BI · December 2025 · 98,656 clean trips

---

## What This Project Is

This is a full-cycle analytics case study built around a real question: in a market as congested, regulated, and competitive as New York City ride-hailing, where exactly is platform margin leaking, who is bearing the cost, and what does a rational market entry look like?

It is not a tutorial. It is not a Kaggle notebook. It is the kind of analysis a strategy or operations analyst would actually produce: data cleaning decisions documented with rationale, formulas explained and defended, findings tied to business decisions, and four distinct stakeholder perspectives built from the same underlying dataset.

The project originated from a personal experience at LaGuardia Airport in December 2025, three cancelled rides, a 43-minute wait, and a set of questions I could not stop thinking about on the flight home.

---

## The Dataset

**Source:** NYC Taxi and Limousine Commission : High Volume For-Hire Vehicle Trip Records  
**Period:** December 2025  
**Raw size:** ~1 million trips  
**Analysis sample:** 98,656 trips after platform and quality filtering  
**Platforms:** HV0003 (Uber) and HV0005 (Lyft) only

The TLC mandates full trip-level disclosure from all HVFHV platforms under NYC Administrative Code Section 19 548. This includes base fare, driver pay, wait times, congestion fees, WAV accessibility flags, and GPS-tracked mileage. NYC is one of the only markets in the US where this data is legally required and publicly available.

---

## Four Stakeholders, Four Dashboards

Rather than building a single generic analysis, every query and every dashboard tab was designed around a specific decision-maker with a specific question.

| Stakeholder | Core Question | Key Finding |
|---|---|---|
| Uber CEO | Where is margin leaking and is growth sustainable? | D10 generates 49.7% of all platform margin. D4 to D6 are structurally loss-making. |
| Lyft CEO | Where is our 181bp take rate edge defensible? | 0% VULNERABLE segments vs. Uber's 45.9%. The edge is real and concentrated in Manhattan. |
| NYC TLC Commissioner | Are drivers being paid fairly and are fees regressive? | Uber: 1.05% violation rate. Lyft: 0.02%. Congestion fees hit short-trip riders at 8.9% of total charge vs. 1.9% for long trips. |
| New Market Entrant | Which zones are genuinely underserved? | Only 2 STRONG ENTRY TARGET zones exist: LaGuardia (score 100) and JFK (score 78.6). Riders paying 3x average fare receive 15% below-average SLA. |

---

## SQL: 11 Queries Across 4 Analytical Themes

```
sql/
  00_setup_view.sql           Enriched view with all derived metrics
  01_market_position.sql      Platform scorecard with window-based market share
  02_demand_heatmap.sql       Borough x time of day demand and SLA matrix
  03_od_corridor_analysis.sql Origin to destination revenue corridors
  04_take_rate_fare_decile.sql NTILE(10) margin decomposition
  05_passenger_price_decomp.sql Fee burden breakdown by component
  06_driver_pay_stress_test.sql TLC minimum pay compliance audit
  07_congestion_burden.sql    Flat-fee regressivity by distance and borough
  08_holiday_demand_stress.sql LAG-based day-over-day revenue cliff analysis
  09_price_volatility.sql     Coefficient of variation by zone
  10_zone_opportunity_matrix.sql Composite entry scoring across 4 dimensions
  11_growth_quality_score.sql  Four-dimension portfolio health scoring
  master_documentation.sql    All queries with full inline documentation
```

### SQL Techniques Demonstrated

- Window functions: `RANK()`, `NTILE()`, `LAG()`, `ROW_NUMBER()`, `SUM() OVER()`
- CTE chains for multi-step transformations
- Aggregate vs. per-row take rate (and why the distinction matters)
- `NULLIF` for safe division throughout
- Double join on the same lookup table for origin and destination geography
- Min-max normalization inside SQL for composite scoring
- `TIMESTAMPDIFF` for wait time and trip duration from raw datetime fields

---

## Key Findings

**Finding 1: Uber's margin problem is in the middle, not the bottom**  
Negative take rate trips peak at fare deciles 4 through 6 ($13 to $24), not at D1. The TLC minimum pay formula creates systematic underpricing in mid-range fares where trip time is high relative to distance. D10 subsidizes the rest.

**Finding 2: Congestion fees are regressive by distance, not borough**  
Flat congestion fees represent 8.9% of total charge for trips under 2 miles and only 1.9% for trips over 20 miles. The burden falls on short-trip riders, disproportionately lower-income Manhattan residents, not outer borough commuters.

**Finding 3: TLC violations peak on long trips**  
Uber's 5 to 10 mile segment has a 2.14% violation rate vs. 0.89% for 0 to 2 mile trips. Congested long rides generate high minimum pay obligations through the time component ($0.57/min) that fares do not always cover. Uber had 750 violations to Lyft's 5, a 150x gap.

**Finding 4: Lyft's portfolio is structurally healthier**  
Growth quality scoring across borough x time segments: Lyft has 0% VULNERABLE segments. Uber has 45.9%. Uber Staten Island Late Night is the worst case: negative take rate, 29.7% SLA, 8.67 minute average wait.

**Finding 5: The airport entry paradox**  
LaGuardia and JFK are the only two STRONG ENTRY TARGET zones in the full dataset. They have the highest average fares ($63 to $76) and the worst SLA (51% to 57%). A new entrant that positions on service reliability at airports can capture both the revenue premium and differentiation simultaneously.

---

## Power BI Dashboard

Four stakeholder tabs, each with its own design language and KPI focus:

- **Tab 1 (Uber CEO):** Black and green. Revenue cliff line chart, margin leak table, borough take rate bars.
- **Tab 2 (Lyft CEO):** White and magenta. Competitive heatmap, price decomposition, zone action matrix.
- **Tab 3 (TLC Commissioner):** Navy and red. Enforcement priority table, congestion regressivity area chart, violation rate by distance.
- **Tab 4 (New Entrant):** Dark navy and gold. Opportunity score matrix, WAV gap stacked bar, airport paradox combo chart.

Screenshots are in `dashboard/screenshots/`.

---

## Repository Structure

```
nyc-rideshare-strategy/
  README.md
  sql/
    00_setup_view.sql through 11_growth_quality_score.sql
    master_documentation.sql
  docs/
    NYC_RideHailing_CaseStudy.docx        Full analytical document with methodology
    NYC_RideHailing_SQL_Appendix.docx     Query-by-query technical documentation
    NYC_RideHailing_Executive_Memo.docx   One-page stakeholder brief
    NYC_RideHailing_Executive_Memo.pdf
    NYC_RideHailing_SQL_Documentation.pdf
  data/
    tab2_borough_both_platforms.csv
    tab2_lyft_time_fare.csv
    tab2_lyft_zones.csv
    tab3_tlc_borough_long.csv
    tab3_tlc_congestion.csv
    tab3_tlc_distance.csv
    tab3_tlc_enforcement_table.csv
    tab4_entrant_zones.csv
    tab4_wav_long.csv
    tab4_airport_paradox.csv
  dashboard/
    screenshots/
```

---

## How to Run

1. Load the TLC HVFHV December 2025 dataset into a MySQL 8.0 database named `nyc_rideshare` with the table name `trips` and the `taxi_zone_lookup` reference table.
2. Run `sql/00_setup_view.sql` to create the enriched view `v_trips_enriched`.
3. Run any of `01` through `11` in any order against `v_trips_enriched`.
4. To reproduce all findings at once, run `sql/master_documentation.sql`.

The data README inside `data/` describes each CSV file and which Power BI tab it feeds.

---

## About

Built by Sai Sourabh Akula, a Business Data Analyst with 5+ years of experience in fraud detection analytics at Unum. MS in Information Systems, University of North Texas.

This project was built to demonstrate full-cycle analytical thinking: from a real observation (a frustrating airport wait), to a structured business question, to SQL implementation, to stakeholder-specific visualization, to documented findings with business recommendations.

**Contact:** github.com/sourabhakula
