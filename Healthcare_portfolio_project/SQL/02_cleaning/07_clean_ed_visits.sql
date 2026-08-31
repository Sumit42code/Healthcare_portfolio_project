/*
Purpose:
Clean and standardise emergency department visit data.

The script:
- converts text columns to appropriate data types;
- standardises categorical values;
- removes exact duplicate rows;
- validates patient and facility relationships;
- identifies invalid triage categories;
- identifies missing or impossible discharge times;
- checks admission consistency.
*/

DROP TABLE IF EXISTS clean.ed_visits;

CREATE TABLE clean.ed_visits (
    visit_id VARCHAR(12) PRIMARY KEY,
    patient_id VARCHAR(12),
    facility_id VARCHAR(10),
    arrival_time TIMESTAMP NOT NULL,
    triage_category SMALLINT,
    discharge_time TIMESTAMP,
    disposition VARCHAR(30) NOT NULL,
    admitted_flag BOOLEAN NOT NULL,
    presenting_group VARCHAR(30) NOT NULL,
    patient_id_issue_flag BOOLEAN NOT NULL,
    facility_id_issue_flag BOOLEAN NOT NULL,
    triage_category_issue_flag BOOLEAN NOT NULL,
    missing_discharge_time_flag BOOLEAN NOT NULL,
    timeline_issue_flag BOOLEAN NOT NULL,
    admission_consistency_issue_flag BOOLEAN NOT NULL,

    CONSTRAINT chk_triage_category
        CHECK (triage_category IS NULL
            OR triage_category BETWEEN 1 AND 5),

    CONSTRAINT chk_ed_disposition
        CHECK (disposition IN ('Discharged','Admitted','Transferred','Left Before Treatment')),

    CONSTRAINT chk_presenting_group
        CHECK (presenting_group IN ('Injury','Respiratory','Cardiac','Abdominal','Neurological','Infection','Other')),

    CONSTRAINT chk_ed_visit_timeline
        CHECK (discharge_time IS NULL OR discharge_time >= arrival_time)
);

/*
Prepare and standardise the raw values
*/
WITH prepared_ed_visits AS (
    SELECT 
        UPPER(NULLIF(BTRIM(visit_id), '')) AS visit_id,

        UPPER(NULLIF(BTRIM(patient_id), '')) AS patient_id_lookup,

        UPPER(NULLIF(BTRIM(facility_id), '')) AS facility_id_lookup,

        NULLIF(BTRIM(arrival_time),'')::TIMESTAMP AS arrival_time,

/*
Keep the original cleaned text version so that
invalid triage values can be identified.
*/
        NULLIF(BTRIM(triage_category),'') AS triage_category_raw,

/*
Convert only valid categories to SMALLINT.
Values such as 0, 6 or 'urgent' become NULL.
This prevents a casting error.
*/
        CASE
            WHEN NULLIF(BTRIM(triage_category), '')
            IN ('1', '2', '3', '4', '5')
            THEN BTRIM(triage_category)::SMALLINT

            ELSE NULL
        END AS triage_category,

        NULLIF(BTRIM(discharge_time),'')::TIMESTAMP AS discharge_time,

        CASE LOWER(NULLIF(BTRIM(disposition), ''))
            WHEN 'discharged'
                THEN 'Discharged'
            WHEN 'admitted'
                THEN 'Admitted'
            WHEN 'transferred'
                THEN 'Transferred'
            WHEN 'left before treatment'
                THEN 'Left Before Treatment'
            ELSE NULL
        END AS disposition,

        CASE LOWER(NULLIF(BTRIM(admitted_flag), ''))
            WHEN 'yes'
                THEN TRUE
            WHEN 'no'
                THEN FALSE
            ELSE NULL
        END AS admitted_flag,

        CASE LOWER(NULLIF(BTRIM(presenting_group), ''))
            WHEN 'injury'
                THEN 'Injury'
            WHEN 'respiratory'
                THEN 'Respiratory'
            WHEN 'cardiac'
                THEN 'Cardiac'
            WHEN 'abdominal'
                THEN 'Abdominal'
            WHEN 'neurological'
                THEN 'Neurological'
            WHEN 'infection'
                THEN 'Infection'
            WHEN 'other'
                THEN 'Other'
            ELSE NULL
        END AS presenting_group

    FROM raw.ed_visits_raw
),
-- Validate relationships and create quality flags
standardised_ed_visits AS (
    SELECT
        ed_visit.visit_id,
        patient.patient_id,
        facility.facility_id,
        ed_visit.arrival_time,
        ed_visit.triage_category,

        /*
        An impossible discharge time is removed from
        the clean value but documented through a flag.
        */
        CASE
            WHEN ed_visit.discharge_time IS NULL
                THEN NULL
            WHEN ed_visit.discharge_time >=
                 ed_visit.arrival_time
                THEN ed_visit.discharge_time
            ELSE NULL
        END AS discharge_time,

        ed_visit.disposition,
        ed_visit.admitted_flag,
        ed_visit.presenting_group,

/*
Required relationship flags
*/
        (patient.patient_id IS NULL) AS patient_id_issue_flag,

        (facility.facility_id IS NULL) AS facility_id_issue_flag,

/*
Invalid or missing triage category
*/
        (ed_visit.triage_category_raw IS NULL
        OR ed_visit.triage_category_raw
        NOT IN ('1', '2', '3', '4', '5')) AS triage_category_issue_flag,

/*
A missing discharge time is considered an issue
unless the patient left before treatment.
*/
        (ed_visit.discharge_time IS NULL
        AND ed_visit.disposition <> 'Left Before Treatment'
        ) AS missing_discharge_time_flag,

/*
Discharge cannot happen before arrival.
*/
        (ed_visit.discharge_time IS NOT NULL
        AND ed_visit.arrival_time IS NOT NULL
        AND ed_visit.discharge_time < ed_visit.arrival_time
        ) AS timeline_issue_flag,

/*
The admitted flag must agree with disposition.
*/
        CASE
            WHEN ed_visit.admitted_flag IS NULL
            THEN TRUE

            WHEN ed_visit.disposition IS NULL
            THEN TRUE

            WHEN ed_visit.disposition = 'Admitted'
            AND ed_visit.admitted_flag = FALSE
            THEN TRUE

            WHEN ed_visit.disposition <> 'Admitted'
            AND ed_visit.admitted_flag = TRUE
            THEN TRUE

            ELSE FALSE
        END AS admission_consistency_issue_flag

    FROM prepared_ed_visits AS ed_visit

    LEFT JOIN clean.patients AS patient
    ON ed_visit.patient_id_lookup = patient.patient_id

    LEFT JOIN clean.facilities AS facility
    ON ed_visit.facility_id_lookup = facility.facility_id
),

--Remove exact duplicates and insert the records

deduplicated_ed_visits AS (
    SELECT DISTINCT
        visit_id,
        patient_id,
        facility_id,
        arrival_time,
        triage_category,
        discharge_time,
        disposition,
        admitted_flag,
        presenting_group,
        patient_id_issue_flag,
        facility_id_issue_flag,
        triage_category_issue_flag,
        missing_discharge_time_flag,
        timeline_issue_flag,
        admission_consistency_issue_flag

    FROM standardised_ed_visits
)

INSERT INTO clean.ed_visits (
    visit_id,
    patient_id,
    facility_id,
    arrival_time,
    triage_category,
    discharge_time,
    disposition,
    admitted_flag,
    presenting_group,
    patient_id_issue_flag,
    facility_id_issue_flag,
    triage_category_issue_flag,
    missing_discharge_time_flag,
    timeline_issue_flag,
    admission_consistency_issue_flag
)

SELECT
    visit_id,
    patient_id,
    facility_id,
    arrival_time,
    triage_category,
    discharge_time,
    disposition,
    admitted_flag,
    presenting_group,
    patient_id_issue_flag,
    facility_id_issue_flag,
    triage_category_issue_flag,
    missing_discharge_time_flag,
    timeline_issue_flag,
    admission_consistency_issue_flag
FROM deduplicated_ed_visits;


--Validate IDs and required values
SELECT
    COUNT(*) AS total_rows,
    COUNT(DISTINCT visit_id) AS unique_visit_ids,
    COUNT(*) FILTER (WHERE visit_id IS NULL) AS missing_visit_ids,
    COUNT(*) FILTER (WHERE arrival_time IS NULL) AS missing_arrival_times,
    COUNT(*) FILTER (WHERE disposition IS NULL) AS missing_dispositions,
    COUNT(*) FILTER (WHERE admitted_flag IS NULL) AS missing_admitted_flags,
    COUNT(*) FILTER (WHERE presenting_group IS NULL) AS missing_presenting_groups
FROM clean.ed_visits;

--Review the quality flags
SELECT
    COUNT(*) FILTER (WHERE patient_id_issue_flag) AS patient_id_issues,

    COUNT(*) FILTER (WHERE facility_id_issue_flag) AS facility_id_issues,

    COUNT(*) FILTER (WHERE triage_category_issue_flag) AS triage_category_issues,

    COUNT(*) FILTER (WHERE missing_discharge_time_flag) AS missing_discharge_time_issues,

    COUNT(*) FILTER (WHERE timeline_issue_flag) AS timeline_issues,

    COUNT(*) FILTER (WHERE admission_consistency_issue_flag) AS admission_consistency_issues

FROM clean.ed_visits;

--Confirm that impossible timelines were removed
SELECT *
FROM clean.ed_visits
WHERE discharge_time IS NOT NULL
AND discharge_time < arrival_time;

--Validate the flags against cleaned values
SELECT *
FROM clean.ed_visits

WHERE
    (patient_id_issue_flag = TRUE
    AND patient_id IS NOT NULL)

    OR (patient_id_issue_flag = FALSE
    AND patient_id IS NULL)

    OR (facility_id_issue_flag = TRUE
    AND facility_id IS NOT NULL)

    OR (facility_id_issue_flag = FALSE
    AND facility_id IS NULL)

    OR (triage_category_issue_flag = TRUE
    AND triage_category IS NOT NULL)

    OR (triage_category_issue_flag = FALSE
    AND triage_category IS NULL)

    OR (timeline_issue_flag = TRUE
    AND discharge_time IS NOT NULL)

    OR (missing_discharge_time_flag = TRUE
    AND discharge_time IS NOT NULL);

--Check admission consistency
SELECT *
FROM clean.ed_visits
WHERE
(disposition = 'Admitted' 
AND admitted_flag = FALSE)
OR (disposition <> 'Admitted'
AND admitted_flag = TRUE);

--Review the cleaned categories
SELECT
    triage_category,
    COUNT(*) AS visit_count
FROM clean.ed_visits
GROUP BY triage_category
ORDER BY triage_category;

SELECT
    disposition,
    admitted_flag,
    COUNT(*) AS visit_count
FROM clean.ed_visits
GROUP BY
    disposition,
    admitted_flag
ORDER BY
    disposition,
    admitted_flag;

SELECT
    presenting_group,
    COUNT(*) AS visit_count
FROM clean.ed_visits
GROUP BY presenting_group
ORDER BY visit_count DESC;

SELECT *
FROM clean.ed_visits;