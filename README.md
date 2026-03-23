# NYC Ride-Hailing Strategy Analysis

open the sql/ folder for all queries and dashboard/screenshots/ for the Power BI tabs.

I got stranded at LaGuardia in December 2025. Three cancelled rides, 43 minutes 
waiting, and I spent the whole flight home thinking about what was actually 
happening underneath that experience. Was it a supply problem? A pricing problem? 
A platform problem? I decided to find out.

The NYC Taxi and Limousine Commission publishes full trip-level data for every 
HVFHV platform operating in the city under NYC Administrative Code Section 19-548. 
Base fare, driver pay, wait times, congestion fees, GPS mileage, all of it. NYC 
is one of the only markets in the US where this is legally required and publicly 
available. I pulled December 2025 data, filtered down to Uber and Lyft only, 
cleaned it to 98,656 trips, and started asking questions.

The question I kept coming back to was not who is winning. It was where is margin 
leaking, who is bearing that cost, and what does a rational market entry actually 
look like in a city this congested and regulated.

Rather than building one generic dashboard I structured the whole thing around 
four specific decision makers. An Uber CEO trying to understand where his platform 
is bleeding margin. A Lyft CEO trying to understand whether her competitive edge 
is real or fragile. An NYC TLC Commissioner trying to figure out if drivers are 
being paid fairly and whether congestion fees are hitting the wrong people. And 
a new market entrant trying to identify which zones are genuinely underserved 
versus just hard.

Each of those four perspectives got its own set of SQL queries and its own 
Power BI dashboard tab with its own design language.

What I found was not what I expected. Uber's margin problem is not at the bottom 
of the fare distribution. It peaks in fare deciles 4 through 6, the $13 to $24 
range, where the TLC minimum pay formula creates systematic underpricing because 
trip time is high relative to distance. Decile 10 is essentially subsidizing the 
middle. That is a structural problem, not a demand problem.

Congestion fees turned out to be regressive by distance, not by borough the way 
most people assume. A flat congestion fee represents 8.9% of total charge for 
a trip under 2 miles and only 1.9% for a trip over 20 miles. The burden falls 
on short trip riders who tend to be lower income Manhattan residents, not outer 
borough commuters making long hauls.

The driver pay finding was stark. Uber had 750 TLC minimum pay violations in 
the dataset. Lyft had 5. That is a 150x gap and it concentrates in the 5 to 10 
mile segment where congested long rides generate high minimum pay obligations 
through the time component that fares do not always cover.

The airport finding is the one I keep thinking about. LaGuardia and JFK are the 
only two zones in the full dataset that score as strong entry targets. They have 
the highest average fares in the entire market, $63 to $76, and the worst service 
levels, 51% to 57% on-time. Riders paying 3x the average fare are getting 15% 
below average service. A new entrant that just shows up reliably at airports 
captures both the revenue premium and the differentiation story at the same time.

The SQL across this project covers window functions, CTE chains, LAG for 
day-over-day comparisons, NTILE for decile decomposition, double joins on the 
same lookup table for origin and destination geography, and min-max normalization 
inside SQL for the composite opportunity scoring. 16 queries total across 4 
analytical themes, all documented in master_documentation.sql.

dataset: NYC TLC HVFHV trip records, December 2025, 98,656 trips after cleaning
tools: MySQL 8.0, Power BI
github: github.com/sourabhakula/nyc-rideshare-strategy
