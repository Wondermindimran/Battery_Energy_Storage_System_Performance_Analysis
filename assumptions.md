# Assumptions Log
## Project: Battery Energy Storage System (BESS) Operations Analysis

**Author:** Muhammad Imran
**Last updated:** 12/07/2026
**Purpose:** This document records every assumption made during data extraction, KPI calculation, and analysis for the NASA Battery Dataset Project. Each assumption is numbered, evidenced, and states what would change if the assumption were wrong.


## ASSUMPTION 01: Rated Capacity Is 2.0 Ahr for All Four Batteries

**Statement:** All four batteries (B0005, B0006, B0007, B0018) share a rated capacity of 2.0 Ahr. All SOH calculations use 2.0 Ahr as the denominator.

**Evidence:** The README.txt file accompanying the dataset states: "The experiments were stopped when the batteries reached end-of-life (EOL) criteria, which was a 30% fade in rated capacity (from 2Ahr to 1.4Ahr)." This explicitly confirms both the rated capacity and the EOL threshold.

**Observation:** Battery B0005 started at 1.8565 Ahr and B0006 started at 2.0353 Ahr. Neither equals exactly 2.0 Ahr. This is expected in real battery testing, manufacturing variation means most times individual cells may be slightly above or below nameplate capacity at commissioning. SOH calculations use the rated 2.0 Ahr, not the first measured capacity, which is consistent with industry standard practice.

**What would change if this assumption is wrong:** If rated capacity were 1.9 Ahr, starting SOH for B0005 would be 97.7% instead of 92.82%. All SOH values would shift proportionally but the relative pattern and EOL crossing cycle would remain identical.


## ASSUMPTION 02: End-of-Life Threshold Is 1.4 Ahr (70% SOH)

**Statement:** A battery is considered to have reached end-of-life when its discharge capacity drops below 1.4 Ahr, representing a 30% fade from the 2.0 Ahr rated capacity.

**Evidence:** Stated explicitly in the dataset README: "end-of-life (EOL) criteria, which was a 30% fade in rated capacity (from 2Ahr to 1.4Ahr)."

**Application:** The is_past_eol flag in clean_discharge.csv is set to 1 for any discharge cycle where capacity_ahr < 1.4. Battery B0005 first crossed this threshold at discharge cycle 125.

**What would change if this assumption is wrong:** If EOL were defined as 20% fade (1.6 Ahr), B0005 would have crossed EOL at an earlier cycle number and the overrun count would be higher. If EOL were defined as 40% fade (1.2 Ahr), B0005 never reached EOL within the experiment period.


## ASSUMPTION 03: Discharge Cycle Number Is Counted Independently of Charge and Impedance Cycles

**Statement:** The discharge_cycle_num column counts only discharge cycles sequentially from 1. Charge cycles and impedance cycles are counted separately in their own sequential counters. The raw cycle_index from the .mat file (which counts all cycle types together) is retained but not used as the primary cycle reference.

**Rationale:** An operations analyst tracking battery health counts discharge cycles because each discharge event is one usage cycle from the application perspective. Counting charge and impedance cycles together with discharge cycles would inflate the cycle number and misrepresent how many times the battery was actually used.

**Example:** The raw cycle at index 3 in B0005 may be an impedance measurement. The 2nd discharge cycle might occur at raw index 4. Using discharge_cycle_num = 2 is more meaningful than raw cycle_index = 4.

**What would change if this assumption is wrong:** If cycle_index were used instead of discharge_cycle_num, all trend charts would have a stretched X-axis and comparisons between batteries would be distorted because different batteries have different numbers of impedance measurements per discharge cycle.


## ASSUMPTION 04: Each Discharge Cycle Capacity Represents the Full Discharge from Fully Charged State

**Statement:** The Capacity field in each discharge cycle represents the total charge delivered from a fully charged battery (approximately 4.2V) down to the discharge cutoff voltage. Each cycle begins from a fully charged state.

**Evidence:** The README describes the experimental protocol: "Charging was carried out in a constant current (CC) mode at 1.5A until the battery voltage reached 4.2V and then continued in a constant voltage (CV) mode until the charge current dropped to 20mA." This confirms that every charge cycle brings the battery to a standardised full charge before the next discharge begins.

**What would change if this assumption is wrong:** If some discharge cycles began from a partially charged state, the capacity reading for those cycles would be artificially low, making degradation appear faster than it is. The experimental protocol described makes this unlikely.


## ASSUMPTION 05: Discharge Cutoff Voltages Differ Per Battery and Are Fixed Per the README

**Statement:** Each battery was discharged to a different voltage cutoff as specified in the dataset README. B0005 was discharged to 2.7V, B0006 to 2.5V, B0007 to 2.2V, and B0018 to 2.5V.

**Evidence:** README states: "Discharge was carried out at a constant current (CC) level of 2A until the battery voltage fell to 2.7V, 2.5V, 2.2V and 2.5V for batteries 5 6 7 and 18 respectively."

**Impact on comparative analysis:** Different cutoff voltages mean different depths of discharge per cycle. B0007, discharged to the lower 2.2V threshold, had more energy extracted per cycle than B0005 at 2.7V. This affects direct capacity comparisons between batteries; B0007 surviving more cycles despite deeper discharge makes its relative resilience even more notable.

**What would change if this assumption is wrong:** If all four batteries used the same cutoff voltage, cross-battery capacity comparisons would be more directly valid. Under the actual different cutoff voltages, cross-battery comparisons should be interpreted with this caveat (difference in cut-off voltages) noted.


## ASSUMPTION 06: Summary Statistics Per Cycle Are Sufficient for Portfolio Analysis

**Statement:** Rather than preserving the full time-series measurements within each cycle (which would produce hundreds of readings per cycle), this analysis extracts summary statistics per cycle: minimum, maximum, and mean values for voltage and temperature, and maximum time for duration. The full time-series data is not stored in the clean CSV files.

**Rationale:** For portfolio-level KPI analysis, cycle-level summaries are sufficient to answer the core business questions related to SOH trend, capacity fade, temperature patterns, and duration changes. Full time-series preservation would produce a dataset of approximately 168 cycles × 250 readings per cycle = 42,000 rows for discharge alone, `which adds complexity without changing the analytical conclusions`.

**What would change if this assumption is wrong:** A full time-series analysis would enable voltage curve shape analysis `(dV/dQ analysis)` and more sophisticated degradation modelling such as incremental capacity analysis. These are advanced techniques beyond the scope of this portfolio project but are noted as a future extension opportunity in the recommendations.


## ASSUMPTION 07: Impedance Measurements Are Taken at Consistent Points in the Cycle Sequence

**Statement:** The 278 impedance measurements for B0005 are treated as representing evenly distributed health checkpoints throughout the battery's life. The impedance cycle number is used as the X-axis for resistance growth charts.

**Limitation:** The exact relationship between impedance measurement number and discharge cycle number is not 1-to-1. Impedance measurements were taken between charge-discharge pairs, approximately every 2 discharge cycles. This means impedance measurement 100 corresponds to approximately discharge cycle 100 in the sequence, but not precisely.

**Impact:** Small misalignment between impedance cycle number and discharge cycle number means the resistance growth curve and the capacity fade curve cannot be overlaid on the exact same X-axis without further processing. In this analysis they are presented as separate charts on the same dashboard page to show the parallel trends rather than an exact overlay.


## ASSUMPTION 08: Charge Duration Reduction Is an Indicator of Capacity Loss

**Statement:** The reduction in charge cycle duration from 169.19 minutes in early life to 154.52 minutes in late life (a 14.67-minute reduction) is interpreted as an indicator of reduced battery capacity rather than a change in charging protocol.

**Rationale:** The charging protocol was constant throughout the experiment, i.e constant current at 1.5A to 4.2V, then constant voltage until current dropped to 20mA. Under a fixed protocol, a battery with lower capacity reaches its voltage target sooner and completes the constant-voltage phase faster because less charge needs to be delivered. Shorter charge time therefore directly reflects reduced capacity.

**What would change if this assumption is wrong:** If the charging current or protocol changed during the experiment `(which the README does not indicate)`, shorter charge time could reflect a protocol change rather than capacity loss. Given the controlled laboratory environment and fixed protocol described, this alternative explanation is considered unlikely.


## ASSUMPTION 09: B0018 Is from a Separate Experiment Batch and Is Treated as Supplementary Data

**Statement:** Battery B0018 ran from July to August 2008 while B0005, B0006, and B0007 ran from April to May 2008. B0018 also has only 53 impedance measurements compared to 278 for the other three. B0018 is included in comparative cycle-count and capacity analysis but excluded from impedance trend comparisons due to insufficient measurement frequency.

**Evidence:** B0005 date range is 2 April to 27 May 2008. B0018 date range is 7 July to 20 August 2008. These non-overlapping periods confirm separate experiment batches.

**Impact:** Treating B0018 as supplementary rather than directly equivalent to B0005-B0007 is the conservative interpretation. Cross-battery comparisons involving B0018 include a caveat noting the different experimental batch and reduced impedance measurement frequency.


## ASSUMPTION 10: Fade Rate Is Calculated as Linear From First to Last Cycle

**Statement:** The capacity fade rate of 3.163 mAhr per cycle for B0005 is calculated as a simple linear rate: (starting capacity − ending capacity) / total cycles × 1000. This treats degradation as if it progressed at a constant rate throughout the battery lifetime.

**Known limitation:** Battery degradation is not perfectly linear. It typically follows a pattern of slow early degradation followed by accelerating late-life fade. The life stage analysis in this project confirms this; the early stage (cycles 1–44) averaged 90.66% SOH while the end-of-life stage (cycles 133–168) averaged 66.40% SOH, showing a steeper decline in later cycles.

**Why linear rate is still used:** The linear rate provides a simple, communicable benchmark for comparing degradation speed across batteries and for the remaining useful life estimation query in the SQL analysis. It is presented alongside the life-stage analysis which captures the non-linear pattern explicitly.

**What would change with a non-linear model:** A `quadratic or exponential degradation model` would give a more accurate remaining useful life estimate, particularly for projecting the final cycles before complete failure. `This is noted as a future enhancement opportunity using Python curve fitting`.
