/*
Purpose:
Create a cleaned referral fact table from
raw.referrals_raw.

Cleaning rules:
- Standardise identifiers and text
- Apply the approved referral-status mapping
- Convert dates and priority scores
- Replace invalid values with NULL
- Flag orphan IDs and invalid timelines
- Remove exact duplicates
- Preserve the original raw table
*/
DROP TABLE IF EXISTS clean.referrals;

CREATE TABLE clean.referrals (
    referral_id VARCHAR(12) PRIMARY KEY,
    patient_id VARCHAR(12),
    department_id VARCHAR(10),
    referral_date DATE NOT NULL,
    urgency VARCHAR(20),
    referral_status VARCHAR(20) NOT NULL,
    first_appointment_date DATE,
    closed_date DATE,
    referral_source VARCHAR(40) NOT NULL,
    priority_score SMALLINT,
    patient_id_issue_flag BOOLEAN NOT NULL,
    department_id_issue_flag BOOLEAN NOT NULL,
    urgency_issue_flag BOOLEAN NOT NULL,
    priority_score_issue_flag BOOLEAN NOT NULL,
    timeline_issue_flag BOOLEAN NOT NULL,

    CONSTRAINT chk_referrals_urgency
    CHECK (urgency IS NULL OR urgency 
    IN ('Routine','Semi-Urgent','Urgent')),

    CONSTRAINT chk_referrals_status
    CHECK (referral_status 
    IN ('Open','Waiting','Booked','Completed','Cancelled','Declined')),

    CONSTRAINT chk_referrals_priority
    CHECK (priority_score IS NULL OR priority_score BETWEEN 1 AND 5),

    CONSTRAINT chk_referrals_first_appointment
    CHECK (first_appointment_date IS NULL OR first_appointment_date >= referral_date),

    CONSTRAINT chk_referrals_closed_date
    CHECK (closed_date IS NULL OR closed_date >= referral_date)

);

/*
Prepare, clean and insert referrals
*/
WITH prepared_referrals AS (
    SELECT 
    UPPER(NULLIF(BTRIM(referral_id), '')) AS referral_id,
    UPPER(NULLIF(BTRIM(patient_id), '')) AS patient_id_lookup,
    UPPER(NULLIF(BTRIM(department_id), '')) AS department_id_lookup,
    NULLIF(BTRIM(referral_date),'')::DATE AS referral_date,
    LOWER(NULLIF(BTRIM(urgency), '')) AS urgency_lookup,
    LOWER(NULLIF(BTRIM(referral_status), '')) AS status_lookup,
    NULLIF(BTRIM(first_appointment_date),'')::DATE AS first_appointment_date,
    NULLIF(BTRIM(closed_date),'')::DATE AS closed_date,
    INITCAP(LOWER(NULLIF(BTRIM(referral_source), ''))) AS referral_source,
    BTRIM(COALESCE(priority_score, '')) AS priority_score_raw
    FROM raw.referrals_raw

),

standardised_referrals AS (
    SELECT
        r.referral_id,
        /* Return the patient ID only when it exists */
        p.patient_id,
        /* Return the department ID only when it exists */
        d.department_id,
        r.referral_date,
        /* Standardise urgency */
        CASE
            WHEN r.urgency_lookup = 'routine'
            THEN 'Routine'

            WHEN r.urgency_lookup = 'semi-urgent'
            THEN 'Semi-Urgent'

            WHEN r.urgency_lookup = 'urgent'
            THEN 'Urgent'

            ELSE NULL
        END AS urgency,

        status_map.standard_value
            AS referral_status,

        /* Remove an impossible appointment date */
        CASE
            WHEN r.first_appointment_date IS NULL
            THEN NULL

            WHEN r.first_appointment_date
                 >= r.referral_date
            THEN r.first_appointment_date

            ELSE NULL
        END AS first_appointment_date,

        /* Remove an impossible closed date */
        CASE
            WHEN r.closed_date IS NULL
            THEN NULL

            WHEN r.closed_date >= r.referral_date
            THEN r.closed_date

            ELSE NULL
        END AS closed_date,

        r.referral_source,

        /* Convert valid priority scores */
        CASE
            WHEN r.priority_score_raw ~ '^[1-5]$'
            THEN r.priority_score_raw::SMALLINT

            ELSE NULL
        END AS priority_score,

        /* Quality flags */
        (p.patient_id IS NULL) AS patient_id_issue_flag,

        (d.department_id IS NULL) AS department_id_issue_flag,

        (r.urgency_lookup IS NULL OR r.urgency_lookup NOT IN ('routine','semi-urgent','urgent')
        ) AS urgency_issue_flag,

        (r.priority_score_raw !~ '^[1-5]$') AS priority_score_issue_flag,

        ((r.first_appointment_date IS NOT NULL AND r.first_appointment_date< r.referral_date)

        OR
        (r.closed_date IS NOT NULL AND r.closed_date < r.referral_date)
        ) AS timeline_issue_flag

    FROM prepared_referrals AS r

    LEFT JOIN clean.patients AS p
        ON r.patient_id_lookup = p.patient_id

    LEFT JOIN clean.departments AS d
        ON r.department_id_lookup = d.department_id

    LEFT JOIN clean.reference_mappings AS status_map
        ON status_map.mapping_group = 'referral_status'
       AND status_map.raw_value_normalised
           = r.status_lookup

),

deduplicated_referrals AS (

    SELECT DISTINCT
        referral_id,
        patient_id,
        department_id,
        referral_date,
        urgency,
        referral_status,
        first_appointment_date,
        closed_date,
        referral_source,
        priority_score,
        patient_id_issue_flag,
        department_id_issue_flag,
        urgency_issue_flag,
        priority_score_issue_flag,
        timeline_issue_flag

    FROM standardised_referrals

)

INSERT INTO clean.referrals (
    referral_id,
    patient_id,
    department_id,
    referral_date,
    urgency,
    referral_status,
    first_appointment_date,
    closed_date,
    referral_source,
    priority_score,
    patient_id_issue_flag,
    department_id_issue_flag,
    urgency_issue_flag,
    priority_score_issue_flag,
    timeline_issue_flag
)

SELECT
    referral_id,
    patient_id,
    department_id,
    referral_date,
    urgency,
    referral_status,
    first_appointment_date,
    closed_date,
    referral_source,
    priority_score,
    patient_id_issue_flag,
    department_id_issue_flag,
    urgency_issue_flag,
    priority_score_issue_flag,
    timeline_issue_flag

FROM deduplicated_referrals;

--Validate row counts

SELECT
    (SELECT COUNT(*)
     FROM raw.referrals_raw) AS raw_rows,

    (SELECT COUNT(*)
     FROM clean.referrals) AS clean_rows,

    (SELECT COUNT(*)
     FROM raw.referrals_raw)

    -

    (SELECT COUNT(*)
     FROM clean.referrals) AS removed_rows;

--Validate identifiers and required values
SELECT
    COUNT(*) AS total_rows,

    COUNT(DISTINCT referral_id) AS unique_referral_ids,

    COUNT(*) FILTER (
        WHERE referral_id IS NULL) AS missing_referral_ids,

    COUNT(*) FILTER (
        WHERE referral_date IS NULL) AS missing_referral_dates,

    COUNT(*) FILTER (
        WHERE referral_status IS NULL) AS missing_referral_statuses,

    COUNT(*) FILTER (
        WHERE referral_source IS NULL) AS missing_referral_sources

FROM clean.referrals;

--Review the quality flags
SELECT
    COUNT(*) FILTER (
        WHERE patient_id_issue_flag) AS patient_id_issues,

    COUNT(*) FILTER (
        WHERE department_id_issue_flag) AS department_id_issues,

    COUNT(*) FILTER (
        WHERE urgency_issue_flag) AS urgency_issues,

    COUNT(*) FILTER (
        WHERE priority_score_issue_flag) AS priority_score_issues,

    COUNT(*) FILTER (
        WHERE timeline_issue_flag) AS timeline_issues

FROM clean.referrals;

--Validate flags against cleaned values
SELECT
    referral_id,
    patient_id,
    department_id,
    urgency,
    priority_score,
    patient_id_issue_flag,
    department_id_issue_flag,
    urgency_issue_flag,
    priority_score_issue_flag

FROM clean.referrals

WHERE
    (patient_id_issue_flag = TRUE 
    AND patient_id IS NOT NULL)
    OR
    (patient_id_issue_flag = FALSE
    AND patient_id IS NULL)
    OR
    (department_id_issue_flag = TRUE
    AND department_id IS NOT NULL)
    OR
    (department_id_issue_flag = FALSE
    AND department_id IS NULL)
    OR
    (urgency_issue_flag = TRUE
    AND urgency IS NOT NULL)
    OR
    (urgency_issue_flag = FALSE
    AND urgency IS NULL)
    OR
    (priority_score_issue_flag = TRUE
    AND priority_score IS NOT NULL)
    OR
    (priority_score_issue_flag = FALSE
    AND priority_score IS NULL);

--Confirm impossible timelines were removed
SELECT
    referral_id,
    referral_date,
    first_appointment_date,
    closed_date,
    timeline_issue_flag

FROM clean.referrals

WHERE first_appointment_date < referral_date
   OR closed_date < referral_date;

/*
Review clean categories
*/
--Urgency
SELECT
    urgency,
    COUNT(*) AS referral_count
FROM clean.referrals
GROUP BY urgency
ORDER BY urgency;

--Referral Status
SELECT
    referral_status,
    COUNT(*) AS referral_count
FROM clean.referrals
GROUP BY referral_status
ORDER BY referral_status;

--Referral status 
SELECT
    referral_status,
    COUNT(*) AS referral_count
FROM clean.referrals
GROUP BY referral_status
ORDER BY referral_status;

--Referral source
SELECT
    referral_source,
    COUNT(*) AS referral_count
FROM clean.referrals
GROUP BY referral_source
ORDER BY referral_source;

select * from clean.referrals;