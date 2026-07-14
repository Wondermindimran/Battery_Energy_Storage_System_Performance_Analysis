-- =============================================
-- Project 2: Battery Energy Storage System
-- SQL Query Bank
-- Author: Muhammad Imran
-- Date: 12-07-2026
-- Dataset: NASA Battery Dataset
-- Batteries: B0005, B0006, B0007, B0018
-- Total discharge cycles: 636
-- =============================================



-- Total discharge cycles per battery

-- Q01: How many discharge cycles did each battery complete?
-- Business question: Which battery ran the longest before end of life?
-- Concept: GROUP BY + COUNT

SELECT
    battery_id,
    COUNT(*)                                    AS total_cycles,
    ROUND(MIN(capacity_ahr), 4)                 AS min_capacity_ahr,
    ROUND(MAX(capacity_ahr), 4)                 AS max_capacity_ahr,
    ROUND(AVG(capacity_ahr), 4)                 AS avg_capacity_ahr
FROM discharge
GROUP BY battery_id
ORDER BY total_cycles DESC;

----------------------------------------------------------------------------------
----------------------------------------------------------------------------------



-- Capacity at start, middle, and end of life per battery

-- Q02: How did capacity change across early, mid, and late life?
-- Business question: At what life stage does degradation accelerate?
-- Concept: CASE WHEN to create life stage buckets + GROUP BY

SELECT
    battery_id,
    CASE
        WHEN discharge_cycle_num <= 44  THEN '1 - Early Life (cycles 1-44)'
        WHEN discharge_cycle_num <= 88  THEN '2 - Mid Life (cycles 45-88)'
        WHEN discharge_cycle_num <= 132 THEN '3 - Late Life (cycles 89-132)'
        ELSE                                 '4 - End of Life (cycles 133+)'
    END                                         AS life_stage,
    COUNT(*)                                    AS cycles_in_stage,
    ROUND(AVG(capacity_ahr), 4)                 AS avg_capacity_ahr,
    ROUND(MIN(capacity_ahr), 4)                 AS min_capacity_ahr
FROM discharge
GROUP BY battery_id, life_stage
ORDER BY battery_id, life_stage;

----------------------------------------------------------------------------------
----------------------------------------------------------------------------------


-- Which battery crossed the EOL threshold first?

-- Q03: At which cycle did each battery cross the 1.4 Ahr EOL threshold?
-- Business question: Which battery failed earliest and how do they compare?
-- Concept: MIN with WHERE filter + subquery

SELECT
    battery_id,
    MIN(discharge_cycle_num)                    AS first_eol_cycle,
    MIN(datetime)                               AS eol_date,
    ROUND(MIN(capacity_ahr), 4)                 AS capacity_at_eol
FROM discharge
WHERE capacity_ahr < 1.4
GROUP BY battery_id
ORDER BY first_eol_cycle ASC;

----------------------------------------------------------------------------------
----------------------------------------------------------------------------------



-- State of Health classification per battery per cycle

-- Q04: Classify each cycle into a SOH health band
-- Business question: How much time did each battery spend in each health zone?
-- Concept: CASE WHEN on soh_pct + GROUP BY with COUNT

SELECT
    battery_id,
    CASE
        WHEN soh_pct >= 90 THEN '1 - Healthy (SOH >= 90%)'
        WHEN soh_pct >= 80 THEN '2 - Good (80-90%)'
        WHEN soh_pct >= 70 THEN '3 - Warning Zone (70-80%)'
        ELSE                    '4 - End of Life (< 70%)'
    END                                         AS health_band,
    COUNT(*)                                    AS cycles_in_band,
    ROUND(AVG(capacity_ahr), 4)                 AS avg_capacity
FROM discharge
GROUP BY battery_id, health_band
ORDER BY battery_id, health_band;

----------------------------------------------------------------------------------
----------------------------------------------------------------------------------




-- Capacity fade rate per battery (mAhr lost per cycle)

-- Q05: How fast is each battery losing capacity on average?
-- Business question: Which battery is degrading fastest per cycle?
-- Concept: First and last values using MIN/MAX on cycle number with subquery

WITH first_last AS (
    SELECT
        battery_id,
        MIN(discharge_cycle_num)    AS first_cycle,
        MAX(discharge_cycle_num)    AS last_cycle
    FROM discharge
    GROUP BY battery_id
),
capacities AS (
    SELECT d.battery_id,
           d.capacity_ahr AS start_cap,
           d2.capacity_ahr AS end_cap,
           fl.last_cycle - fl.first_cycle + 1 AS total_cycles
    FROM discharge d
    JOIN discharge d2
        ON d.battery_id = d2.battery_id
        AND d2.discharge_cycle_num = (SELECT MAX(discharge_cycle_num)
                                      FROM discharge
                                      WHERE battery_id = d.battery_id)
    JOIN first_last fl ON fl.battery_id = d.battery_id
    WHERE d.discharge_cycle_num = fl.first_cycle
)
SELECT
    battery_id,
    ROUND(start_cap, 4)                                         AS start_capacity_ahr,
    ROUND(end_cap, 4)                                           AS end_capacity_ahr,
    total_cycles,
    ROUND((start_cap - end_cap) / total_cycles * 1000, 4)      AS fade_rate_mahr_per_cycle,
    ROUND((start_cap - end_cap) / start_cap * 100, 2)          AS total_fade_pct
FROM capacities
ORDER BY fade_rate_mahr_per_cycle DESC;

----------------------------------------------------------------------------------
----------------------------------------------------------------------------------



-- Weekly average capacity per battery

-- Q06: How did weekly average capacity trend over time?
-- Business question: Is degradation consistent week-over-week or accelerating?
-- Concept: GROUP BY battery_id + week_num + AVG

SELECT
    battery_id,
    week_num,
    COUNT(*)                                    AS cycles_that_week,
    ROUND(AVG(capacity_ahr), 4)                 AS avg_capacity_ahr,
    ROUND(AVG(soh_pct), 2)                      AS avg_soh_pct,
    ROUND(MIN(capacity_ahr), 4)                 AS min_capacity_ahr
FROM discharge
GROUP BY battery_id, week_num
ORDER BY battery_id, week_num;

----------------------------------------------------------------------------------
----------------------------------------------------------------------------------



-- Cycles where capacity dropped more than 1% vs previous cycle

-- Q07: Flag cycles with sudden large capacity drops
-- Business question: Were there any abrupt degradation events or was it gradual?
-- Concept: LAG window function + threshold filter

WITH with_prev AS (
    SELECT
        battery_id,
        discharge_cycle_num,
        datetime,
        capacity_ahr,
        LAG(capacity_ahr, 1) OVER (
            PARTITION BY battery_id
            ORDER BY discharge_cycle_num
        )                                       AS prev_capacity
    FROM discharge
)
SELECT
    battery_id,
    discharge_cycle_num,
    datetime,
    ROUND(capacity_ahr, 4)                      AS capacity_ahr,
    ROUND(prev_capacity, 4)                     AS prev_capacity_ahr,
    ROUND((capacity_ahr - prev_capacity)
          / NULLIF(prev_capacity, 0) * 100, 2)  AS change_pct,
    'INVESTIGATE'                               AS flag
FROM with_prev
WHERE prev_capacity IS NOT NULL
  AND (capacity_ahr - prev_capacity) / NULLIF(prev_capacity, 0) < -0.01
ORDER BY change_pct ASC
LIMIT 20;

----------------------------------------------------------------------------------
----------------------------------------------------------------------------------




 -- Impedance resistance growth over time

-- Q08: How did internal resistance change across impedance measurements?
-- Business question: Is rising resistance a reliable predictor of capacity fade?
-- Concept: GROUP BY battery + imp_cycle bucket to show trend

SELECT
    battery_id,
    CASE
        WHEN imp_cycle_num <= 25  THEN '1 - Early'
        WHEN imp_cycle_num <= 50  THEN '2 - Quarter'
        WHEN imp_cycle_num <= 100 THEN '3 - Mid'
        WHEN imp_cycle_num <= 200 THEN '4 - Late'
        ELSE                          '5 - End'
    END                                         AS measurement_stage,
    COUNT(*)                                    AS readings,
    ROUND(AVG(Re_ohms), 6)                      AS avg_Re_ohms,
    ROUND(AVG(Rct_ohms), 6)                     AS avg_Rct_ohms,
    ROUND(MAX(Re_ohms), 6)                      AS max_Re_ohms,
    ROUND(MAX(Rct_ohms), 6)                     AS max_Rct_ohms
FROM impedance
GROUP BY battery_id, measurement_stage
ORDER BY battery_id, measurement_stage;

----------------------------------------------------------------------------------
----------------------------------------------------------------------------------



-- Temperature during discharge across life stages

-- Q09: Does discharge temperature increase as the battery ages?
-- Business question: Can we detect aging through temperature monitoring alone?
-- Concept: CASE WHEN life stage + AVG temperature per stage

SELECT
    battery_id,
    CASE
        WHEN discharge_cycle_num <= 44  THEN '1 - Early Life'
        WHEN discharge_cycle_num <= 88  THEN '2 - Mid Life'
        WHEN discharge_cycle_num <= 132 THEN '3 - Late Life'
        ELSE                                 '4 - End of Life'
    END                                         AS life_stage,
    ROUND(AVG(temp_mean_c), 3)                  AS avg_discharge_temp,
    ROUND(MAX(temp_max_c), 3)                   AS peak_temp_ever,
    ROUND(AVG(duration_mins), 2)                AS avg_duration_mins
FROM discharge
GROUP BY battery_id, life_stage
ORDER BY battery_id, life_stage;

----------------------------------------------------------------------------------
----------------------------------------------------------------------------------



-- Which battery had the most consistent performance?

-- Q10: Measure performance consistency using standard deviation of capacity
-- Business question: Which battery is most predictable and reliable?
-- Concept: Standard deviation as a variability measure

SELECT
    battery_id,
    COUNT(*)                                        AS total_cycles,
    ROUND(AVG(capacity_ahr), 4)                     AS avg_capacity_ahr,
    ROUND(MAX(capacity_ahr) - MIN(capacity_ahr), 4) AS capacity_range_ahr,
    ROUND(AVG(duration_mins), 2)                    AS avg_duration_mins,
    ROUND(MAX(duration_mins) - MIN(duration_mins), 2) AS duration_range_mins
FROM discharge
GROUP BY battery_id
ORDER BY capacity_range_ahr ASC;

----------------------------------------------------------------------------------
----------------------------------------------------------------------------------



--  Remaining useful life estimate based on fade rate

-- Q11: At current degradation rate, how many cycles remain until EOL?
-- Business question: When should we plan for battery replacement?
-- Concept: CTE for fade rate calculation + projected cycles remaining

WITH fade_rates AS (
    SELECT
        battery_id,
        MAX(discharge_cycle_num)                AS cycles_completed,
        MAX(capacity_ahr)                       AS starting_capacity,
        MIN(capacity_ahr)                       AS current_min_capacity,
        (MAX(capacity_ahr) - MIN(capacity_ahr))
            / MAX(discharge_cycle_num)          AS fade_per_cycle
    FROM discharge
    GROUP BY battery_id
)
SELECT
    battery_id,
    cycles_completed,
    ROUND(current_min_capacity, 4)              AS lowest_capacity_seen,
    ROUND(fade_per_cycle * 1000, 4)             AS fade_mahr_per_cycle,
    ROUND((current_min_capacity - 1.4)
          / NULLIF(fade_per_cycle, 0), 0)       AS est_cycles_to_eol,
    CASE
        WHEN current_min_capacity < 1.4
        THEN 'PAST EOL — Replace Now'
        WHEN (current_min_capacity - 1.4)
             / NULLIF(fade_per_cycle, 0) < 20
        THEN 'CRITICAL — Replace Within 20 Cycles'
        WHEN (current_min_capacity - 1.4)
             / NULLIF(fade_per_cycle, 0) < 50
        THEN 'WARNING — Plan Replacement'
        ELSE 'HEALTHY — Monitor Regularly'
    END                                         AS replacement_status
FROM fade_rates
ORDER BY est_cycles_to_eol ASC;

----------------------------------------------------------------------------------
----------------------------------------------------------------------------------



--  Charge duration trend over time

-- Q12: Did charge duration change as the battery aged?
-- Business question: Is it taking longer or shorter to charge the battery over time?
-- Concept: GROUP BY week_num on charge table + trend comparison

SELECT
    battery_id,
    CASE
        WHEN charge_cycle_num <= 44  THEN '1 - Early Life'
        WHEN charge_cycle_num <= 88  THEN '2 - Mid Life'
        WHEN charge_cycle_num <= 132 THEN '3 - Late Life'
        ELSE                              '4 - End of Life'
    END                                         AS life_stage,
    COUNT(*)                                    AS cycles,
    ROUND(AVG(duration_secs) / 60, 2)          AS avg_charge_duration_mins,
    ROUND(MIN(duration_secs) / 60, 2)          AS min_charge_mins,
    ROUND(MAX(duration_secs) / 60, 2)          AS max_charge_mins
FROM charge
GROUP BY battery_id, life_stage
ORDER BY battery_id, life_stage;

----------------------------------------------------------------------------------
----------------------------------------------------------------------------------




-- Batteries ranked by total energy delivered over their lifetime

-- Q13: Which battery delivered the most total energy across all cycles?
-- Business question: Which battery gave the most value before end of life?
-- Concept: Approximate energy by summing capacity × nominal voltage

SELECT
    battery_id,
    COUNT(*)                                    AS total_cycles,
    ROUND(SUM(capacity_ahr), 2)                 AS total_capacity_delivered_ahr,
    ROUND(SUM(capacity_ahr) * 3.6, 2)          AS approx_total_energy_wh,
    ROUND(AVG(capacity_ahr), 4)                 AS avg_capacity_per_cycle,
    RANK() OVER (ORDER BY SUM(capacity_ahr) DESC) AS energy_rank
FROM discharge
GROUP BY battery_id
ORDER BY energy_rank;

----------------------------------------------------------------------------------
----------------------------------------------------------------------------------




-- Cycles where both temperature AND capacity were at worst levels simultaneously

-- Q14: Find cycles with both high temperature and low capacity
-- Business question: Does high temperature cause capacity drops or just correlate?
-- Concept: Multiple WHERE conditions + ranking to find worst combined events

SELECT
    battery_id,
    discharge_cycle_num,
    datetime,
    ROUND(capacity_ahr, 4)                      AS capacity_ahr,
    ROUND(soh_pct, 2)                           AS soh_pct,
    ROUND(temp_max_c, 2)                        AS peak_temp_c,
    ROUND(temp_mean_c, 2)                       AS mean_temp_c,
    ROUND(duration_mins, 1)                     AS duration_mins
FROM discharge
WHERE soh_pct < 75
  AND temp_max_c > 38
ORDER BY soh_pct ASC, temp_max_c DESC
LIMIT 20;

----------------------------------------------------------------------------------
----------------------------------------------------------------------------------




-- Full health scorecard per battery

-- Q15: Complete performance scorecard for all four batteries
-- Business question: Which battery performed best overall across all dimensions?
-- Concept: Multiple aggregations + CASE WHEN scoring + RANK

WITH scorecard AS (
    SELECT
        battery_id,
        COUNT(*)                                            AS total_cycles,
        ROUND(MAX(capacity_ahr), 4)                        AS peak_capacity,
        ROUND(MIN(capacity_ahr), 4)                        AS floor_capacity,
        ROUND(AVG(capacity_ahr), 4)                        AS avg_capacity,
        ROUND(AVG(soh_pct), 2)                             AS avg_soh,
        ROUND((MAX(capacity_ahr)-MIN(capacity_ahr))
              / MAX(capacity_ahr) * 100, 2)                AS total_fade_pct,
        ROUND((MAX(capacity_ahr)-MIN(capacity_ahr))
              / COUNT(*) * 1000, 4)                        AS fade_per_cycle_mahr,
        ROUND(AVG(temp_mean_c), 2)                         AS avg_temp,
        SUM(CASE WHEN is_past_eol = 1 THEN 1 ELSE 0 END)  AS cycles_past_eol
    FROM discharge
    GROUP BY battery_id
)
SELECT
    battery_id,
    total_cycles,
    peak_capacity,
    floor_capacity,
    avg_soh,
    total_fade_pct,
    fade_per_cycle_mahr,
    cycles_past_eol,
    RANK() OVER (ORDER BY total_fade_pct ASC)               AS longevity_rank,
    RANK() OVER (ORDER BY avg_soh DESC)                     AS health_rank,
    CASE
        WHEN total_fade_pct < 26 THEN 'Best'
        WHEN total_fade_pct < 30 THEN 'Good'
        WHEN total_fade_pct < 35 THEN 'Average'
        ELSE                          'Poor'
    END                                                     AS overall_rating
FROM scorecard
ORDER BY longevity_rank;

----------------------------------------------------------------------------------
----------------------------------------------------------------------------------