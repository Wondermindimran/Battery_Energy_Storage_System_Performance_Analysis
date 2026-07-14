# Battery Energy Storage System (BESS) Operations Analysis

**A data analytics portfolio project by Muhammad Imran**

[![Tableau Dashboard](https://img.shields.io/badge/Dashboard-Tableau_Public-blue)](https://public.tableau.com/views/BATTERYHEALTHANALYSIS/BatteryHealthOverview?:language=en-US&:sid=&:redirect=auth&:display_count=n&:origin=viz_share_link)


![alt text](<Battery Health Overview.png>)

## Business Problem

Battery B0005 was subjected to continuous charge and discharge cycling until it reached end-of-life. The operations team needed to understand how battery capacity degraded over time, when the battery crossed the end-of-life threshold, what physical mechanisms drove that degradation, and how much operational impact the capacity loss created in terms of reduced discharge duration.

This analysis tracks 168 discharge cycles across 55 days, quantifies the degradation trajectory from first cycle to end of life, identifies internal resistance growth as the root cause of capacity fade, and provides three evidence-based recommendations for condition-based battery management.


## Dataset

| File | Format | Contents | Cycles |
|---|---|---|---|
| B0005.mat | MATLAB .mat | Discharge, charge, impedance cycles | 616 total |
| B0006.mat | MATLAB .mat | Discharge, charge, impedance cycles | 616 total |
| B0007.mat | MATLAB .mat | Discharge, charge, impedance cycles | 616 total |
| B0018.mat | MATLAB .mat | Discharge, charge, impedance cycles | 319 total |

**Source:** NASA Prognostics Center of Excellence — Battery Data Set
https://ti.arc.nasa.gov/tech/dash/groups/pcoe/prognostic-data-repository

**Battery type:** 18650-format Lithium-ion cells

**Rated capacity:** 2.0 Ahr

**Experiment period (B0005):** 2 April 2008 – 27 May 2008 (55 days)

**End-of-life criterion:** 30% capacity fade from rated — 1.4 Ahr threshold

**Note:** This analysis focuses on Battery B0005 as the primary subject. The dataset includes three additional batteries (B0006, B0007, B0018) which were analysed comparatively. B0005 primary analysis period is 55 days with 168 discharge cycles, 170 charge cycles, and 278 impedance measurements.


## Tools Used

| Tool | Purpose |
|---|---|
| Python 3 (scipy.io) | Extract nested MATLAB .mat structure into pandas DataFrames |
| Python 3 (pandas) | Data cleaning, feature engineering, KPI calculation |
| Python (matplotlib, seaborn) | EDA charts and visualisations |
| SQLite + DB Browser | SQL analysis (15 business queries) |
| Tableau Public | Interactive 3-page dashboard |
| VS Code + Jupyter Notebook | Development environment |
| GitHub | Version control and portfolio hosting |


## Key Data Engineering Challenge

The NASA Battery dataset is stored in MATLAB .mat format, a nested binary structure that cannot be opened with standard CSV tools. The primary data engineering challenge in this project was extracting usable tabular data from this format.

Each battery file contains a top-level cycle array where every element is a dictionary with keys for cycle type (charge, discharge, or impedance), ambient temperature, timestamp, and a nested data dictionary containing the actual measurements. Discharge cycles contain up to 7 time-series measurement arrays per cycle. Extracting summary statistics from each cycle into a flat DataFrame required looping through 616 cycles per battery and computing per-cycle aggregations.

This extraction work; which most portfolio projects never encounter, demonstrates the ability to work with real engineering data formats used by NASA, research institutions, and industrial BESS operators.


## Key Data Quality Findings

1. **MATLAB .mat format required custom extraction.** Standard pd.read_csv() does not work. Used scipy.io.loadmat() with simplify_cells=True to flatten the nested structure into accessible Python dictionaries.

2. **Zero null values across all extracted records.** All 168 discharge cycles, 170 charge cycles, and 278 impedance measurements were fully populated with no missing readings.

3. **Zero duplicate cycles.** Each cycle index is unique within its battery. No duplicate timestamps or repeated measurements.

4. **Timestamp stored as MATLAB date vector.** The time field is a 6-element array [year, month, day, hour, minute, second] rather than a standard datetime string. Required manual reconstruction using datetime(int(t[0]), int(t[1]), int(t[2]), int(t[3]), int(t[4])).

5. **Capacity field exists only in discharge cycles.** Charge and impedance cycles do not record capacity directly. All SOH and fade calculations are derived from discharge cycle capacity values only.


## KPIs Defined and Calculated

| KPI | Formula | Unit | Result (B0005) |
|---|---|---|---|
| State of Health (SOH) | Capacity Ahr / Rated Capacity (2.0) × 100 | % | 92.82% start → 66.25% end |
| Capacity Fade % | (Start Cap − Current Cap) / Start Cap × 100 | % | 28.62% total fade |
| Fade Rate | Total capacity lost / Total cycles × 1000 | mAhr per cycle | 3.163 mAhr per cycle |
| EOL Flag | Capacity < 1.4 Ahr | Boolean | Crossed at cycle 125 |
| Discharge Duration | Max(Time vector) / 60 | Minutes | 60.42 → 46.72 mins |
| Re Growth % | (Re end − Re start) / Re start × 100 | % | +12.02% |
| Rct Growth % | (Rct end − Rct start) / Rct start × 100 | % | +7.68% |
| Cycles Past EOL | Count of cycles where capacity < 1.4 Ahr | Count | 44 of 168 (26.2%) |


## Key Findings

1. **Battery crossed EOL threshold at cycle 125 and continued operating for 44 more cycles.** Starting SOH was 92.82%. Ending SOH was 66.25%. The battery spent 55.4% of its total operational cycles in the Warning or End-of-Life SOH zones.

2. **Discharge duration fell 22.68% from 60.42 minutes to 46.72 minutes over the battery lifetime.** Any operational plan assuming a fixed discharge window will overestimate available backup time by up to 23% at end of life.

3. **Internal resistance growth is the confirmed physical mechanism behind capacity fade.** Electrolyte resistance (Re) grew 12.02% and charge transfer resistance (Rct) grew 7.68% from first to last impedance measurement. Rising resistance converts more energy to heat per cycle, reducing useful energy delivery.

4. **Degradation was progressive and predictable, not sudden.** Life stage analysis shows a consistent SOH decline from 90.66% in early life to 66.40% at end of life, with no abrupt step-changes. This confirms that condition-based monitoring could detect approaching EOL well in advance.

5. **Charge duration shortened by 14.67 minutes from early to late life.** A degraded battery charges faster because it holds less energy. This counterintuitive signal (shorter charge time) is an early operational warning of reduced capacity.


## Recommendations

1. **Implement SOH-based automated alerts** at 80% (yellow), 75% (amber), and 70% (red) thresholds to prevent the 44-cycle overrun beyond EOL observed in this dataset.

2. **Recalibrate dispatch plans every 25 cycles** using the most recent 10-cycle average discharge duration as the operational baseline, preventing systematic overestimation of backup duration.

3. **Include electrochemical impedance measurements every 20 cycles** as a condition-based health check. Flag batteries for inspection when Re exceeds 15% growth from commissioning baseline, enabling replacement planning before capacity reaches the Warning zone.


## Project Structure

```
Project_2_BESS/
├── data/
│   ├── raw/
│   │   ├── B0005.mat
│   │   ├── B0006.mat
│   │   ├── B0007.mat
│   │   └── B0018.mat
│   └── clean/
│       ├── clean_discharge.csv
│       ├── clean_charge.csv
│       └── clean_impedance.csv
├── sql/
│   ├── bess.db
│   └── bess_queries.sql
├── notebooks/
│   └── bess_analysis.ipynb
├── dashboard/
│   └── [Tableau Public link — see badge above]
├── reports/
│   ├── BESS_Performance_Report.pdf
│   ├── chart1_capacity_fade.png
│   ├── chart2_soh_trend.png
│   ├── chart3_impedance_growth.png
│   ├── chart4_temperature_trend.png
│   └── chart5_discharge_duration.png
├── data_dictionary.md
├── assumptions.md
├── requirements.txt
└── README.md
```


## How to Reproduce This Analysis

1. Clone this repository
   ```
   git clone https://github.com/Wondermindimran/Battery_Energy_Storage_System_Performance_Analysis/
   ```

2. Install dependencies
   ```
   pip install -r requirements.txt
   ```

3. Open the notebook
   ```
   cd notebooks
   jupyter notebook bess_analysis.ipynb
   ```

4. Run all cells in order from top to bottom. Clean CSV files will be saved to data/clean/ and the SQLite database will be created at sql/bess.db.

5. Open sql/bess.db in DB Browser for SQLite and run the queries from sql/bess_queries.sql.

6. Open Tableau Public and connect to data/clean/clean_discharge.csv and data/clean/clean_impedance.csv to build or view the dashboard.


## References

1. Saha, B. and Goebel, K. (2007). Battery Data Set. NASA Ames Prognostics Data Repository. NASA Ames Research Center, Moffett Field, CA.
   https://ti.arc.nasa.gov/tech/dash/groups/pcoe/prognostic-data-repository

2. Saha, B. and Goebel, K. (2009). Modeling Li-ion Battery Capacity Depletion in a Particle Filtering Framework. Proceedings of the Annual Conference of the Prognostics and Health Management Society.

3. Plett, G.L. (2015). Battery Management Systems, Volume I: Battery Modeling. Artech House. ISBN 978-1-63081-023-8.


## Limitations

- Primary analysis covers Battery B0005 only — a single 18650-format Li-ion cell
- Laboratory conditions with controlled constant-current cycling do not replicate real-world variable load profiles
- No calendar aging is captured — only cycle aging from continuous charge-discharge
- Cell-level findings may not directly scale to module or pack-level BESS performance
- No financial data available — operational impact estimates are based on duration and capacity metrics only


## Author

**Muhammad Imran**
`Data Analyst | SQL, Python, Power BI, Tableau | Interest in renewable energy, operations & sustainability analytics`

`https://www.linkedin.com/in/muhammad-imran-96318a23b/?lipi=urn%3Ali%3Apage%3Ad_flagship3_detail_base%3BHBUN4PrwSx%2B8TG9ykgaGuA%3D%3D`



