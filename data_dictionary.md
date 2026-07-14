# Data Dictionary
## Project 2 — Battery Energy Storage System (BESS) Operations Analysis

**Dataset:** NASA Prognostics Center of Excellence; Battery Data Set
**Battery focus:** B0005 (primary), B0006, B0007, B0018 (comparative)
**Author:** Muhammad Imran
**Last updated:** 13/07/2026


## How to Read This Document

This document defines every column in every file used in this project, i.e the raw source format, the three extracted clean CSV files, and every derived column added during feature engineering. The raw data is stored in MATLAB .mat format and was converted to tabular CSV format using scipy.io in Python.


## RAW SOURCE FORMAT — .mat Files

### File List

| File | Battery | Total Cycles | Discharge | Charge | Impedance |
|---|---|---|---|---|---|
| B0005.mat | Battery 5 | 616 | 168 | 170 | 278 |
| B0006.mat | Battery 6 | 616 | 168 | 170 | 278 |
| B0007.mat | Battery 7 | 616 | 168 | 170 | 278 |
| B0018.mat | Battery 18 | 319 | 132 | 134 | 53 |

### Raw Structure

Each .mat file contains a top-level key matching the battery name (B0005, B0006, B0007, B0018). Under that key is a single field called cycle, which is an array of dictionaries. Each dictionary represents one operational cycle and contains four fields:

**type:** String. The operation type. One of three values: charge, discharge, or impedance.

**ambient_temperature:** Float. The ambient air temperature during the cycle in degrees Celsius. Value is 24 for all B0005, B0006, and B0007 cycles. Varies for B0018.

**time:** Array of 6 floats. The start time of the cycle stored as a MATLAB date vector in the format [year, month, day, hour, minute, second]. Requires manual reconstruction into a Python datetime object.

**data:** Nested dictionary. Contains the actual time-series measurements for the cycle. The fields available within data differ depending on the cycle type, as documented in each section below.


## FILE 1: clean_discharge.csv

**Rows:** 168 (one row per discharge cycle for B0005)
**Columns:** 19 (9 raw extracted + 10 derived)
**Granularity:** One row represents one complete discharge cycle


### battery_id

**Data type:** String
**Unique values:** 1 (B0005 in primary analysis)
**Values:** B0005, B0006, B0007, B0018 in full comparative dataset

**Plain English:** The identifier for the battery. Corresponds directly to the filename and the top-level key in the .mat file.

**Why it matters:** Primary grouping column for all multi-battery comparisons. Without this column, discharge cycles from different batteries cannot be distinguished.


### discharge_cycle_num

**Data type:** Integer
**Range:** 1 to 168
**Null values:** 0

**Plain English:** A sequential counter of discharge cycles for this battery, starting at 1. This is not the raw cycle_index from the .mat file — it counts only discharge cycles, skipping charge and impedance cycles. Cycle 1 is the first discharge. Cycle 168 is the last.

**Why it matters:** The primary X-axis for every trend chart in this project. All capacity fade, SOH, and duration trends are plotted against this column.


### datetime

**Data type:** datetime64 after conversion
**Range:** 2008-04-02 15:25:00 to 2008-05-27 20:45:00
**Null values:** 0

**Plain English:** The start date and time of the discharge cycle, reconstructed from the MATLAB date vector using datetime(int(t[0]), int(t[1]), int(t[2]), int(t[3]), int(t[4])).

**Cleaning applied:** Converted from 6-element MATLAB array to Python datetime, then cast to pandas datetime64.

**Why it matters:** Enables calendar-based analysis — days elapsed, week number, and date-range filtering.


### capacity_ahr

**Data type:** Float
**Unit:** Ampere-hours (Ahr)
**Range:** 1.2875 to 1.8565 Ahr
**Null values:** 0

**Plain English:** The total electrical charge delivered during this discharge cycle, measured in ampere-hours. This is the most important column in the entire dataset. It is the direct measure of how much energy the battery was able to store and deliver at this point in its life. As the battery ages, this value declines.

**Source:** data['Capacity'] field within each discharge cycle in the .mat file. This field exists only in discharge cycles — not in charge or impedance cycles.

**Why it matters:** Every health KPI in this project is derived from this column. SOH, capacity fade percentage, EOL flag, and RUL estimation all depend on capacity_ahr being correctly extracted.


### voltage_min

**Data type:** Float
**Unit:** Volts (V)
**Range:** 2.4557 to 2.7000 V
**Null values:** 0

**Plain English:** The lowest voltage recorded during this discharge cycle. As a battery discharges, its terminal voltage drops progressively. The discharge ends when voltage reaches the cutoff threshold — 2.7V for B0005. The minimum voltage therefore represents the voltage at which the discharge was terminated.

**Source:** np.min(data['Voltage_measured']) across the discharge time series.


### voltage_max

**Data type:** Float
**Unit:** Volts (V)
**Range:** 4.0 to 4.2229 V
**Null values:** 0

**Plain English:** The highest voltage recorded during this discharge cycle. This occurs at the very start of discharge when the battery is fully charged. A fully charged Li-ion cell has a terminal voltage close to 4.2V. Significant decline in voltage_max over cycles indicates reduced charge acceptance.

**Source:** np.max(data['Voltage_measured']) across the discharge time series.


### voltage_mean

**Data type:** Float
**Unit:** Volts (V)
**Range (observed):** approximately 3.4 to 3.6 V
**Null values:** 0

**Plain English:** The average terminal voltage across the entire discharge cycle. The nominal voltage for a Li-ion cell is 3.6V. As the battery ages and internal resistance increases, average discharge voltage declines slightly because more voltage is lost to internal resistance.

**Source:** np.mean(data['Voltage_measured']) across the discharge time series.


### temp_min_c

**Data type:** Float
**Unit:** Degrees Celsius (°C)
**Null values:** 0

**Plain English:** The minimum temperature recorded at the battery surface during this discharge cycle. Typically occurs at the start of discharge before internal resistance begins generating heat.

**Source:** np.min(data['Temperature_measured']) across the discharge time series.


### temp_max_c

**Data type:** Float
**Unit:** Degrees Celsius (°C)
**Range:** approximately 30 to 41.45°C
**Null values:** 0

**Plain English:** The peak temperature reached at the battery surface during this discharge cycle. Higher peak temperatures indicate more internal heat generation, which correlates with higher internal resistance.

**Source:** np.max(data['Temperature_measured']) across the discharge time series.

**Why it matters:** Rising temp_max_c over cycles is a secondary indicator of increasing internal resistance and progressive degradation.


### temp_mean_c

**Data type:** Float
**Unit:** Degrees Celsius (°C)
**Range:** 32.03°C (early life mean) to 33.43°C (end-of-life mean)
**Overall mean:** 32.79°C
**Null values:** 0

**Plain English:** The average battery surface temperature across the full discharge cycle. Used in the life-stage temperature analysis to confirm that discharge temperature rises gradually as the battery ages.

**Source:** np.mean(data['Temperature_measured']) across the discharge time series.


### duration_secs

**Data type:** Float
**Unit:** Seconds
**Range:** approximately 2,792 to 3,690 seconds
**Null values:** 0

**Plain English:** The total duration of the discharge cycle in seconds, taken as the maximum value in the time series vector for that cycle.

**Source:** np.max(data['Time']) from the discharge cycle time vector.

**Note:** This column is converted to duration_mins (see derived columns) for all analysis and reporting because minutes are more intuitive for operational interpretation.


### ambient_temp_c

**Data type:** Float
**Unit:** Degrees Celsius (°C)
**Value:** 24°C (constant for all B0005 cycles)
**Null values:** 0

**Plain English:** The ambient room temperature during the cycle as recorded at the start of the experiment. Constant at 24°C for batteries B0005, B0006, and B0007 because the experiment was conducted in a controlled laboratory environment.

**Source:** cycle['ambient_temperature'] from the top-level cycle structure.


### DERIVED COLUMNS — Added During Feature Engineering


### soh_pct

**Data type:** Float
**Unit:** Percentage (%)
**Range:** 64.37% to 92.82%
**Derived from:** capacity_ahr / 2.0 × 100

**Plain English:** State of Health — the current capacity of the battery expressed as a percentage of its rated capacity of 2.0 Ahr. A brand new battery at exactly 2.0 Ahr has SOH of 100%. Battery B0005 started at 92.82% SOH because its actual first-cycle capacity was 1.8565 Ahr, slightly below the 2.0 Ahr nameplate rating. End-of-life is defined as 70% SOH (1.4 Ahr). The battery ended at 66.25% SOH.

**Why it matters:** SOH is the standard metric used by battery management systems worldwide to communicate battery health to operators. Using this metric makes the analysis immediately understandable to anyone working in energy storage.


### capacity_fade_pct

**Data type:** Float
**Unit:** Percentage (%)
**Range:** 0.00% to 28.62%
**Derived from:** (first_cycle_capacity − current_capacity) / first_cycle_capacity × 100

**Plain English:** The percentage of capacity lost relative to the battery's own first recorded discharge capacity. Starts at 0% on cycle 1 and increases progressively. Reached 28.62% at the final recorded cycle.

**Why it matters:** Measures degradation relative to the battery's own starting point rather than against rated capacity. This is more accurate than using rated capacity as the baseline when the battery does not start at exactly 2.0 Ahr.


### is_past_eol

**Data type:** Integer (0 or 1)
**Values:** 0 = within safe operating range, 1 = past end-of-life threshold
**Cycles flagged as 1:** 44 of 168
**Derived from:** 1 if capacity_ahr < 1.4 else 0

**Plain English:** A binary flag indicating whether this discharge cycle was conducted at below end-of-life capacity. Any cycle where the battery was operating with less than 1.4 Ahr capacity is flagged as past EOL. Battery B0005 first crossed this threshold at cycle 125 and all subsequent 44 cycles are flagged 1.

**Why it matters:** Enables direct counting of cycles operated beyond safe capacity. The finding that 26.2% of all cycles were conducted past EOL is derived from this column.


### duration_mins

**Data type:** Float
**Unit:** Minutes
**Range:** 46.54 to 61.50 minutes
**Mean:** 52.16 minutes
**Derived from:** duration_secs / 60

**Plain English:** The discharge duration converted from seconds to minutes for readability. Average duration in the first 10 cycles was 60.42 minutes. Average in the final 10 cycles was 46.72 minutes — a 22.68% reduction over the battery lifetime.

**Why it matters:** Duration is the operationally meaningful measure of battery performance. Capacity in Ahr is a technical number. Duration in minutes is what an operator directly experiences.


### capacity_rolling10

**Data type:** Float
**Unit:** Ahr
**Derived from:** 10-cycle rolling average of capacity_ahr per battery

**Plain English:** A smoothed version of capacity_ahr using a 10-cycle rolling window. Reduces cycle-to-cycle noise and makes the underlying degradation trend visible on charts. Used as the dashed line overlay on the capacity fade chart.


### capacity_change

**Data type:** Float
**Unit:** Ahr
**Derived from:** capacity_ahr.diff() per battery group

**Plain English:** The capacity change from one cycle to the previous cycle. Negative values indicate capacity loss. Large negative values in a single cycle are flagged as anomaly events. The first cycle per battery returns NaN because there is no prior cycle to compare.


### days_elapsed

**Data type:** Integer
**Unit:** Days
**Range:** 0 to 55
**Derived from:** (datetime − battery's first datetime).dt.days

**Plain English:** The number of calendar days since the first discharge cycle for this battery. Day 0 is the date of the first discharge. Day 55 is the final discharge cycle date.


### week_num

**Data type:** Integer
**Range:** 1 to 8
**Derived from:** days_elapsed // 7 + 1

**Plain English:** The week number of the experiment, starting at 1 for the first week. Used for weekly trend analysis in SQL queries and dashboard filters.


### life_stage

**Data type:** Categorical string
**Values:** Early (1–44), Mid (45–88), Late (89–132), End (133+)
**Derived from:** pd.cut on discharge_cycle_num with 4 equal bins

**Plain English:** A label categorising each cycle into one of four life stages based on cycle number. Divides the 168-cycle life into four roughly equal segments of 44 cycles each. Used in the life-stage analysis table showing how SOH, temperature, and discharge duration changed across the battery lifetime.


## FILE 2: clean_impedance.csv

**Rows:** 278 (one row per impedance measurement for B0005)
**Columns:** 6


### imp_cycle_num

**Data type:** Integer
**Range:** 1 to 278

**Plain English:** Sequential counter of impedance measurements, starting at 1. Impedance measurements were taken approximately every 2 discharge cycles throughout the experiment, giving 278 total measurements for B0005.


### Re_ohms

**Data type:** Float
**Unit:** Ohms
**Range:** 0.04356 to 0.06352 Ohms
**Starting value:** 0.04467 Ohms
**Ending value:** 0.05004 Ohms
**Growth:** +12.02%

**Plain English:** Electrolyte resistance — the resistance of the liquid electrolyte inside the battery through which lithium ions travel between the positive and negative electrodes. As the battery ages, the electrolyte degrades chemically, increasing this resistance. Higher Re means more energy is lost as heat per cycle rather than being stored or delivered as useful output.

**Source:** data['Re'] from each impedance cycle in the .mat file. This is a pre-computed scalar value derived from electrochemical impedance spectroscopy (EIS) measurements.

**Why it matters:** Re is a leading indicator of battery aging. It begins rising before visible capacity decline becomes severe, making it useful for predicting remaining useful life. The 12.02% growth in Re from first to last measurement is the primary physical evidence of aging in this dataset.


### Rct_ohms

**Data type:** Float
**Unit:** Ohms
**Range:** 0.06488 to 0.08976 Ohms
**Starting value:** 0.06946 Ohms
**Ending value:** 0.07479 Ohms
**Growth:** +7.68%

**Plain English:** Charge transfer resistance — the resistance at the electrode surface where the electrochemical reaction takes place. Represents how difficult it is for lithium ions to transfer between the electrolyte and the solid electrode material. Increases with electrode degradation, SEI (solid electrolyte interphase) layer growth, and lithium plating.

**Source:** data['Rct'] from each impedance cycle in the .mat file.

**Why it matters:** Together with Re, Rct provides a two-dimensional picture of internal battery health. Re tracks electrolyte degradation. Rct tracks electrode degradation. Both increasing together confirms progressive aging across multiple battery components simultaneously.


## FILE 3: clean_charge.csv

**Rows:** 170 (one row per charge cycle for B0005)
**Columns:** 7


### charge_cycle_num

**Data type:** Integer
**Range:** 1 to 170

**Plain English:** Sequential counter of charge cycles. 170 charge cycles were performed — two more than the 168 discharge cycles because the experiment began and ended with charge operations.


### duration_secs

**Data type:** Float
**Unit:** Seconds
**Early life average:** 10,151 seconds (169.19 minutes)
**Late life average:** 9,271 seconds (154.52 minutes)
**Charge duration reduction:** 14.67 minutes

**Plain English:** The total duration of the charge cycle. A degraded battery accepts charge faster because it has less capacity to fill. The 14.67-minute reduction in charge duration from early to late life is an early operational warning indicator of reduced capacity — a counterintuitive signal where shorter charge time indicates worse battery health.


### temp_max_c

**Data type:** Float
**Unit:** Degrees Celsius
**Maximum recorded:** 31.19°C

**Plain English:** Peak battery temperature during the charge cycle. Charging generates less heat than discharging for this battery type at the current levels used in the experiment.


### temp_mean_c

**Data type:** Float
**Unit:** Degrees Celsius
**Overall mean:** 25.81°C

**Plain English:** Average battery temperature during the charge cycle. Notably lower than discharge temperature mean (32.79°C), which is expected because the charge current (1.5A) is lower than the discharge current (2.0A) and generates less resistive heating.
