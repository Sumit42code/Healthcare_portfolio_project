# Healthcare Access & Patient Flow Analytics

 An end-to-end healthcare analytics portfolio project using PostgreSQL, SQL and Power BI to investigate referral access, outpatient appointment performance and emergency-department patient flow.

| Project detail | Description |
|---|---|
| **Project type** | Graduate data analytics portfolio project |
| **Data** | Synthetic healthcare records only |
| **Snapshot date** | 1 August 2026 |
| **Core tools** | PostgreSQL, SQL, Power BI and Power Query |
| **Status** | SQL workflow complete; Power BI dashboard in development |

---

## Contents

- [Project overview](#project-overview)
- [Business problem](#business-problem)
- [Project architecture](#project-architecture)
- [Dataset](#dataset)
- [Business questions](#business-questions)
- [Project workflow](#project-workflow)
- [Data quality approach](#data-quality-approach)
- [Database and analytics design](#database-and-analytics-design)
- [KPI definitions](#kpi-definitions)
- [Selected findings](#selected-findings)
- [Power BI dashboard](#power-bi-dashboard)
- [Validation](#validation)
- [Running the project](#running-the-project)
- [Limitations and future improvements](#limitations-and-future-improvements)
- [Skills demonstrated](#skills-demonstrated)
- [Insights](#Insights)

---

## Project overview

This project analyses a fictional New Zealand healthcare network containing facilities, departments, patients, referrals, outpatient appointments and emergency-department visits.

The Project follows a complete analytical workflow:

1. Preserve the original source data.
2. Profile and clean the data in PostgreSQL.
3. Document known data-quality limitations with issue flags.
4. Apply database constraints and performance-supporting indexes.
5. Validate cross-table consistency and KPI eligibility.
6. Create reusable analytical views.
7. Answer operational questions with SQL.
8. Build a Power BI semantic model and dashboard.

---

## Business problem

Healthcare managers need a reliable way to identify where patients are experiencing delays and where operational performance may require further investigation.

The main decision question is:

> **Where should management focus operational improvement to reduce delays and improve patient flow?**

The analysis combines referral, appointment and emergency-department activity so users can move from a network summary to region, facility and department-level detail.

### Project objectives

- Measure the size and age of the referral backlog.
- Identify departments with high referral volumes or long waits.
- Compare outpatient no-show rates and clinic waiting-time performance.
- Measure performance against department-level access targets.
- Analyse ED demand, length of stay, admission and patients leaving before treatment.
- Identify repeat ED visits within seven days.
- Retain analytically useful records without hiding known source-data problems.
- Present the results through an explainable and reproducible reporting workflow.

---

## Project architecture

![Healthcare analytics data pipeline](Healthcare_Analytics_Pipeline.png)

The database uses three schemas with separate responsibilities:

| Schema | Purpose |
|---|---|
| `raw` | Preserves source values for traceability and profiling |
| `clean` | Stores typed, standardised and quality-controlled records |
| `analytics` | Provides reusable, business-friendly reporting views |

This layered design prevents reporting logic from being mixed with source ingestion or cleaning rules.

---

## Dataset

The project uses synthetic data created for educational and portfolio purposes. It contains no information about real patients, employees or healthcare organisations.

### Clean data summary

| Table | Rows | Grain | Purpose |
|---|---:|---|---|
| `facilities` | 8 | One row per facility | Facility location, type and capacity |
| `departments` | 40 | One row per department | Specialty and operational targets |
| `patients` | 18,000 | One row per patient | Demographics and enrolment information |
| `referrals` | 32,000 | One row per referral | Referral status, urgency, dates and priority |
| `appointments` | 65,000 | One row per appointment | Scheduling, attendance and clinic timestamps |
| `ed_visits` | 22,000 | One row per ED visit | Arrival, triage, disposition and discharge |

### Time coverage

- **Historical activity:** 1 January 2025 to 31 July 2026.
- **Project snapshot date:** 1 August 2026.
- **Referral backlog:** measured as a point-in-time population at the snapshot date.
- **Appointment and ED measures:** calculated across the selected activity period.

---

## Business questions

### Referral access

1. How is referral volume changing by month and status?
2. Which departments have the largest referral backlog?
3. How is the backlog distributed across waiting-time bands?
4. What percentage of eligible referrals received a first appointment within target?

### Appointment performance

5. How many appointments occurred each month by status?
6. Which departments have the highest no-show rates?
7. Which departments are meeting their clinic waiting-time targets?
8. Does the no-show rate differ by booking channel?
9. Does the no-show rate differ by patient deprivation quintile?

### Emergency-department flow

10. How is ED demand changing each month?
11. Which facilities have the longest average ED stays?
12. What percentage of ED visits resulted in admission or the patient leaving before treatment?
13. What are the most common ED presenting groups?
14. How many ED visits occurred within seven days of the patient's previous discharge?

---

## Project workflow

### 1. Load and preserve the source data

- Imported the CSV files into the `raw` schema.
- Retained original values so every cleaning decision could be traced.
- Reconciled source and raw-table row counts.

![alt text](image.png)



### 2. Profile the raw data

- Counted total rows and distinct identifiers.
- Identified nulls, blanks, duplicates and sentinel values.
- Checked identifier formats, categories, numeric ranges and date coverage.
- Used anti-joins to identify unmatched relationship keys.
- Reviewed event timelines before selecting cleaning treatments.

![alt text](image-1.png)

### 3. Clean and standardise

- Trimmed whitespace and standardised category labels.
- Converted blanks and selected sentinel values to `NULL`.
- Converted text fields to appropriate PostgreSQL data types.
- Removed exact duplicate source rows.
- Preserved useful activity records where possible.
- Added flags when a retained record was unsafe for a specific calculation.

![alt text](image-2.png)


### 4. Protect and optimise the database

- Added primary and foreign keys after cleaning.
- Created 12 targeted indexes for common joins and date filters.
- Used `ANALYZE` to update PostgreSQL query-planner statistics.
- Avoided unnecessary indexes on low-cardinality fields.

![alt text](image-3.png)


![alt text](image-4.png)


### 5. Validate the clean model

- Tested appointment-to-referral patient and department consistency.
- Checked that healthcare activity did not occur before a valid birth date.
- Confirmed that analytical joins did not multiply fact-table rows.
- Measured candidate, eligible and excluded records for important KPIs.
![alt text](image-5.png)

![alt text](image-7.png)

![alt text](image-8.png)

![alt text](image-9.png)


### 6. Build the analytical layer

- Created one-row-per-event views for referrals, appointments and ED visits.
- Added reusable flags, dates, waiting-time calculations and descriptive fields.
- Kept final aggregations and rankings in the business-analysis file.

![alt text](image-10.png)

![alt text](image-11.png)

![alt text](image-12.png)


### 7. Build Power BI

- Loaded analysis-ready data rather than raw tables.
- Created dimension-to-fact relationships and a continuous date table.
- Built base counts before percentage and average measures.
- Reconciled unfiltered Power BI measures with independently checked SQL totals.

> Dashboard Link
---

## Data quality approach

The project does not remove a record simply because one field is problematic. Cleaning decisions depend on whether the intended value can be determined safely.

| Data issue | Treatment |
|---|---|
| Harmless formatting difference | Standardise the value |
| Exact duplicate | Retain one copy |
| Invalid but safely recoverable value | Correct and document the treatment |
| Invalid and uncertain value | Set the analytical value to `NULL` and flag it |
| Valid missing value | Retain `NULL` |
| Unusable record | Exclude with a documented reason |

### Purpose of flag columns

Issue and eligibility flags preserve transparency without unnecessarily deleting complete records. For example:

- A visit with an invalid discharge timeline can remain in visit-volume reporting but is excluded from ED length-of-stay calculations.
- A completed appointment with missing clinic timestamps can remain in appointment counts but is excluded from waiting-time KPIs.
- An unmatched facility identifier is not linked to an invented facility; the clean identifier becomes `NULL` and the issue is recorded.

This allows each KPI to use a clearly defined and defensible population.

---

## Database and analytics design

### Main relationships

| Parent | Child | Key |
|---|---|---|
| `facilities` | `departments` | `facility_id` |
| `patients` | `referrals` | `patient_id` |
| `departments` | `referrals` | `department_id` |
| `patients` | `appointments` | `patient_id` |
| `departments` | `appointments` | `department_id` |
| `referrals` | `appointments` | `referral_id` |
| `patients` | `ed_visits` | `patient_id` |
| `facilities` | `ed_visits` | `facility_id` |

Foreign keys permit `NULL` where an invalid source relationship was deliberately removed, but reject non-null identifiers that do not exist in the parent table.

### Analytical views

| View | Grain | Primary use |
|---|---|---|
| `analytics.vw_referral_analysis` | One row per referral | Referral volume, backlog, wait bands and access targets |
| `analytics.vw_appointment_analysis` | One row per appointment | Attendance, no-shows, clinic waits and target performance |
| `analytics.vw_ed_visit_analysis` | One row per ED visit | ED demand, length of stay, disposition and repeat visits |

Reusable joins and derived fields are created in `01_create_analytics_views.sql`. Business-specific aggregation and ranking remain in `02_business_analysis.sql`.

---

## KPI definitions

| KPI | Definition | Main exclusions or context |
|---|---|---|
| Backlog referrals | Referrals in the agreed open or waiting statuses at the snapshot date | Point-in-time measure |
| Backlog wait days | Snapshot date minus referral date | Backlog population only |
| Backlog over target % | Over-target referrals divided by target-eligible backlog referrals | Requires valid urgency, department and target |
| No-show rate | No-show appointments divided by attendance-eligible appointments | Uses the agreed attendance denominator |
| Average appointment wait | Average minutes from check-in to seen time | Valid clinic timestamps only |
| Seen within target % | Appointments within the department target divided by target-eligible appointments | Requires valid department and timestamps |
| Average ED length of stay | Average hours from arrival to discharge | Valid completed ED timelines only |
| Admission rate | Admitted visits divided by the agreed ED population | Uses consistent admission logic |
| Left before treatment | Visits with the agreed left-before-treatment disposition | Reported as a count or separately defined rate |
| Seven-day ED return | Arrival within seven days of the patient's previous valid ED discharge | Measures repeat ED use, not hospital readmission |

SQL percentages are reported from `0` to `100`. Equivalent Power BI rate measures return a decimal from `0` to `1` and are formatted as percentages.

---

## Selected findings

Because the dataset is synthetic, these findings demonstrate analytical interpretation rather than real healthcare performance.

| Finding | Evidence | Business interpretation |
|---|---|---|
| Referral demand was relatively stable | Monthly referrals ranged from 1,547 to 1,742 | Backlog pressure is unlikely to be explained by one isolated demand spike |
| A substantial backlog was over target | 8,035 backlog referrals; 5,888 were target-eligible and 4,924 were over target (83.63%) | Target-eligible backlog should be prioritised by wait duration and department |
| First-appointment target performance was close to half | 7,420 of 14,674 target-eligible referrals met target (50.56%) | Access performance requires further investigation, particularly for urgent pathways |
| Booking channel differences were small | No-show rates ranged from 12.49% for Clinic bookings to 13.41% for Phone bookings | Booking channel alone is unlikely to explain most non-attendance |
| No clear deprivation gradient was visible | Quintile no-show rates ranged from 12.48% to 13.22% | The data does not support a simple claim that no-shows consistently rise with deprivation |
| Injury was the largest ED presenting group | 5,289 visits, representing 24.04% of ED activity | Injury demand is an important consideration for ED staffing and service planning |

These results identify where further investigation should begin; they do not establish the causes of operational performance.

---

## Power BI dashboard

The report is organised into two decision-focused pages.

### Page 1: Healthcare access and appointment performance

- Date, region, facility and department slicers.
- Backlog, over-60-day backlog and over-target KPI cards.
- No-show rate and seen-within-target KPI cards.
- Top departments by referral backlog.
- Backlog waiting-band comparison.
- Appointment-performance comparison.
- Region, facility and department performance matrix.

### Page 2: Emergency-department flow

- Date, region and facility slicers.
- Total ED visits, average length of stay, admission rate and left-before-treatment cards.
- Monthly ED demand trend.
- Facility-level ED performance comparison.
- Disposition and presenting-group composition.
- Seven-day repeat-visit analysis.

### Semantic model

The Power BI model follows a star-schema approach:

- **Dimensions:** `DimDate`, `DimFacilities`, `DimDepartments` and `DimPatients`.
- **Facts:** `FactReferrals`, `FactAppointments` and `FactEDVisits`.
- **Relationships:** one-to-many with single-direction filtering from dimensions to facts.
- **Measures:** base counts, eligible populations, numerators, rates and averages.

Department filters are not applied to ED visuals because ED visits do not contain a valid department relationship.

---

## Validation

Validation is performed throughout the workflow rather than only at the end.

| Layer | Validation question |
|---|---|
| Structural | Does each table preserve its intended grain? |
| Field | Are required fields, categories, ranges and data types valid? |
| Relationship | Do linked records agree across tables? |
| Timeline | Are the recorded event sequences possible? |
| Analytical | Do joins preserve fact-table row counts? |
| KPI readiness | Which records are safe for each calculation? |
| Reporting | Do Power BI results match independently checked SQL totals? |

### Expected evidence

- Six clean tables at their intended grain.
- Eight enforced foreign-key relationships.
- Twelve manually selected analytical indexes.
- No unexpected row multiplication in analytical joins.
- Known data-quality limitations quantified through flags and eligibility counts.
- Unfiltered Power BI totals reconciled with SQL.

A known flagged limitation is not automatically a validation failure. A failure means the workflow broke an agreed rule; a flag documents a limitation that was deliberately retained.

---

## Running the project

### Requirements

- PostgreSQL and a compatible SQL client such as `psql` or pgAdmin.
- Power BI Desktop.
- Permission to create a PostgreSQL database and schemas.

### SQL execution order

1. Create the database schemas and raw tables.
2. Load the synthetic CSV files into the `raw` schema.
3. Run the profiling files:
   - `01_profile_identifiers.sql`
   - `02_profile_values_and_ranges.sql`
   - `03_profile_relationships_and_timelines.sql`
4. Run the mapping and cleaning files:
   - `01_create_reference_mappings.sql`
   - `02_clean_facilities.sql`
   - `03_clean_departments.sql`
   - `04_clean_patients.sql`
   - `05_clean_referrals.sql`
   - `06_clean_appointments.sql`
   - `07_clean_ed_visits.sql`
5. Protect and validate the clean model:
   - `01_add_constraints.sql`
   - `02_create_indexes.sql`
   - `03_validate_clean_data.sql`
6. Build and query the analytical layer:
   - `01_create_analytics_views.sql`
   - `02_business_analysis.sql`
7. Open `Healthcare_Access_Dashboard.pbix`, update the PostgreSQL connection and refresh the model.
8. Confirm that the unfiltered Power BI measures match the validated SQL totals.

Database passwords, cloud credentials and other secrets must never be committed to the repository.

---

## Limitations and future improvements

### Limitations

- The data is synthetic and does not represent a real healthcare system.
- Operational targets are illustrative and are not official national standards.
- The analysis is descriptive and does not establish causal relationships.
- Some quality issues were deliberately retained and documented.
- No clinical outcome, treatment-effectiveness or patient-safety conclusions should be drawn.
- The dashboard is a portfolio demonstration rather than a production-governed reporting system.

### Future improvements

- Complete and visually validate both Power BI pages.
- Add final dashboard and semantic-model screenshots.
- Add a KPI definitions or report-information page in Power BI.
- Add automated regression checks for critical row counts and measures.
- Add one `EXPLAIN ANALYZE` example demonstrating index impact.
- Optionally deploy PostgreSQL to Amazon RDS and source files to a private S3 bucket after the local workflow is fully validated.

Cloud services or advanced tools should be added only when they solve a defined project requirement.

---

## Skills demonstrated

### SQL and PostgreSQL

- Data profiling, cleaning and validation.
- Multi-table joins and anti-joins.
- Common table expressions and conditional aggregation.
- Window functions including `LAG()`.
- Date arithmetic and interval calculations.
- Primary keys, foreign keys and indexes.
- Reusable analytical views.
- Cross-table consistency and KPI-readiness checks.

### Power BI

- Star-schema modelling.
- Date-dimension creation and chronological sorting.
- DAX counts, eligible populations, rates and averages.
- Slicers, KPI cards, trends, rankings and matrices.
- Conditional formatting and visual interactions.
- SQL-to-dashboard reconciliation.

### Analytical communication

- Translating operational problems into measurable questions.
- Defining metric populations, denominators and exclusions.
- Separating findings from possible explanations.
- Communicating limitations and recommended areas for investigation.

---

## Insights

[Click Here for Insights](Insights.md)
---

## Author

**Sumit Uniyal**  
Graduate Data Analyst / Healthcare Data Analyst candidate  
New Zealand
