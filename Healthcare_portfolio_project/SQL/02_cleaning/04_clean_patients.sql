/*
Purpose:
Create a cleaned patient dimension from raw.patients_raw.

Cleaning rules:
- Standardise patient IDs
- Apply approved gender mappings
- Standardise ethnicity and city
- Convert dates from TEXT to DATE
- Convert valid deprivation quintiles to INTEGER
- Replace unusable values with NULL
- Add quality flags
- Remove exact duplicate records
- Preserve the original raw table
*/

/*
Create the clean patients table
*/
DROP TABLE IF EXISTS clean.patients;

CREATE TABLE clean.patients (
    patient_id VARCHAR(12) PRIMARY KEY,
    date_of_birth DATE,
    gender VARCHAR(30) NOT NULL,
    ethnicity VARCHAR(30),
    city VARCHAR(60) NOT NULL,
    deprivation_quintile SMALLINT,
    enrolment_date DATE NOT NULL,
    ethnicity_missing_flag BOOLEAN NOT NULL,
    date_of_birth_issue_flag BOOLEAN NOT NULL,
    deprivation_quintile_issue_flag BOOLEAN NOT NULL,

    CONSTRAINT chk_patients_gender
    CHECK (gender IN ('Female','Male','Gender Diverse','Unknown')),

    CONSTRAINT chk_patients_ethnicity
    CHECK (ethnicity IS NULL 
            OR ethnicity IN ('European','Maori','Pacific','Asian','Other')),

    CONSTRAINT chk_patients_deprivation
    CHECK (deprivation_quintile IS NULL
        OR deprivation_quintile BETWEEN 1 AND 5),

    CONSTRAINT chk_patients_birth_date
    CHECK (date_of_birth IS NULL
        OR date_of_birth BETWEEN DATE '1900-01-01' AND DATE '2026-08-01'),

    CONSTRAINT chk_patients_enrolment_date
    CHECK (enrolment_date <= DATE '2026-08-01'),

    CONSTRAINT chk_patients_date_order
    CHECK (date_of_birth IS NULL OR enrolment_date >= date_of_birth)

);

/*
Clean and standardise patients
*/
WITH standardised_patients AS (
    SELECT 
    UPPER(NULLIF(BTRIM(patient_id), '')) AS patient_id,

        /* Clean date of birth */
        CASE
            WHEN LOWER(BTRIM(COALESCE(date_of_birth, ''))) 
            IN ('','n/a','na','unknown','null')
            THEN NULL
            WHEN BTRIM(date_of_birth)::DATE BETWEEN DATE '1900-01-01' AND DATE '2026-08-01'
            THEN BTRIM(date_of_birth)::DATE
            ELSE NULL
        END AS date_of_birth,

        /* Prepare gender for mapping */

        LOWER(NULLIF(BTRIM(gender), '')) AS gender_lookup,

        /* Clean ethnicity */

        CASE WHEN LOWER(BTRIM(COALESCE(ethnicity, ''))) IN ('','n/a','na','unknown','null')
            THEN NULL

            ELSE INITCAP(LOWER(BTRIM(ethnicity)))
        END AS ethnicity,

        /* Clean city */

        INITCAP(LOWER(NULLIF(BTRIM(city), ''))) AS city,

        /* Clean deprivation quintile */

        CASE
            WHEN BTRIM(
                COALESCE(deprivation_quintile, '')) ~ '^[1-5]$'

            THEN BTRIM(deprivation_quintile)::SMALLINT

            ELSE NULL
        END AS deprivation_quintile,

        /* Convert enrolment date */

        NULLIF(BTRIM(enrolment_date),'')::DATE AS enrolment_date,

        /* Ethnicity missing flag */

        CASE
            WHEN LOWER(BTRIM(COALESCE(ethnicity, '')))
            IN ('','n/a','na','unknown','null')
            THEN TRUE

            ELSE FALSE
        END AS ethnicity_missing_flag,

        /*
This prevents invalid data from entering calculations while preserving evidence that there was a source-data problem.

Without the flag, an analyst would not know whether the value was genuinely missing or removed during cleaning.
        */

        /* Date-of-birth issue flag */

        CASE
            WHEN LOWER(BTRIM(COALESCE(date_of_birth, ''))) 
            IN ('','n/a','na','unknown','null')
            THEN TRUE

            WHEN BTRIM(date_of_birth)::DATE
            NOT BETWEEN DATE '1900-01-01' AND DATE '2026-08-01'
            THEN TRUE

            ELSE FALSE
        END AS date_of_birth_issue_flag,

        /* Deprivation issue flag */

        CASE
            WHEN BTRIM(COALESCE(deprivation_quintile, '')) !~ '^[1-5]$'
            THEN TRUE

            ELSE FALSE
        END AS deprivation_quintile_issue_flag

    FROM raw.patients_raw

),

deduplicated_patients AS (

    SELECT DISTINCT
        patient_id,
        date_of_birth,
        gender_lookup,
        ethnicity,
        city,
        deprivation_quintile,
        enrolment_date,
        ethnicity_missing_flag,
        date_of_birth_issue_flag,
        deprivation_quintile_issue_flag
    FROM standardised_patients

)

INSERT INTO clean.patients (
    patient_id,
    date_of_birth,
    gender,
    ethnicity,
    city,
    deprivation_quintile,
    enrolment_date,
    ethnicity_missing_flag,
    date_of_birth_issue_flag,
    deprivation_quintile_issue_flag
)

SELECT
    p.patient_id,
    p.date_of_birth,
    gender_map.standard_value AS gender,
    p.ethnicity,
    p.city,
    p.deprivation_quintile,
    p.enrolment_date,
    p.ethnicity_missing_flag,
    p.date_of_birth_issue_flag,
    p.deprivation_quintile_issue_flag

FROM deduplicated_patients AS p

LEFT JOIN clean.reference_mappings AS gender_map
    ON gender_map.mapping_group = 'gender'
   AND gender_map.raw_value_normalised = p.gender_lookup;

/*
Validate row counts
*/
SELECT
    (SELECT COUNT(*)
     FROM raw.patients_raw) AS raw_rows,

    (SELECT COUNT(*)
     FROM clean.patients) AS clean_rows,

    (SELECT COUNT(*)
     FROM raw.patients_raw)

    -

    (SELECT COUNT(*)
     FROM clean.patients) AS removed_rows;

/*
Validate uniqueness and required values
*/
SELECT
    COUNT(*) AS total_rows,
    COUNT(DISTINCT patient_id) AS unique_patient_ids,

    COUNT(*) FILTER (
        WHERE patient_id IS NULL) AS missing_patient_ids,

    COUNT(*) FILTER (
        WHERE gender IS NULL) AS missing_gender,

    COUNT(*) FILTER (WHERE city IS NULL) AS missing_city,

    COUNT(*) FILTER (
        WHERE enrolment_date IS NULL) AS missing_enrolment_dates

FROM clean.patients;

/*
Review the quality flags
*/
SELECT
    COUNT(*) FILTER (WHERE ethnicity_missing_flag) AS missing_ethnicity_records,
    COUNT(*) FILTER (WHERE date_of_birth_issue_flag) AS date_of_birth_issues,
    COUNT(*) FILTER (WHERE deprivation_quintile_issue_flag) AS deprivation_quintile_issues
FROM clean.patients;

/*
Validate flags against cleaned values.
This section checks whether each quality flag agrees with its corresponding cleaned value.
*/
SELECT * FROM clean.patients

WHERE
    /* Flag says ethnicity is missing, but ethnicity still has a value */
    (ethnicity_missing_flag = TRUE AND ethnicity IS NOT NULL)
    OR
    /* Ethnicity is missing, but the flag says there is no problem */
    (ethnicity_missing_flag = FALSE AND ethnicity IS NULL)
    OR
    /* Flag says birth date has a problem, but the date was retained */
    (date_of_birth_issue_flag = TRUE AND date_of_birth IS NOT NULL)
    OR
    /* Birth date is missing, but the flag says there is no problem */
    (date_of_birth_issue_flag = FALSE AND date_of_birth IS NULL)
    OR
    /* Flag says deprivation has a problem, but the value was retained */
    (deprivation_quintile_issue_flag = TRUE AND deprivation_quintile IS NOT NULL)
    OR
    /* Deprivation is missing, but the flag says there is no problem */
    ( deprivation_quintile_issue_flag = FALSE AND deprivation_quintile IS NULL);

/*
Review cleaned categories
*/
--GENDER
SELECT gender,
count(*) AS patient_count
FROM clean.patients
GROUP BY gender
ORDER BY gender;

--Ethnicity
SELECT
    ethnicity,
    COUNT(*) AS patient_count
FROM clean.patients
GROUP BY ethnicity
ORDER BY ethnicity;

/*
We have 360 ethnicity NULL record
we'll count ethnicity completeness
we cant guess, replace with ethnicity with the most common category.
so for analysis we'll keep it like that
*/

SELECT
    COUNT(*) AS total_patients,

    COUNT(*) FILTER (WHERE ethnicity IS NULL) AS missing_ethnicity,

    ROUND(COUNT(*) FILTER (WHERE ethnicity IS NOT NULL) * 100.0 / COUNT(*),2) AS ethnicity_completeness_percentage

FROM clean.patients;

--CITY 
SELECT
    city,
    COUNT(*) AS patient_count
FROM clean.patients
GROUP BY city
ORDER BY city;

--Deprivation quintile
SELECT
    deprivation_quintile,
    COUNT(*) AS patient_count
FROM clean.patients
GROUP BY deprivation_quintile
ORDER BY deprivation_quintile;

--Review affected records
SELECT * FROM clean.patients
WHERE ethnicity_missing_flag = TRUE
   OR date_of_birth_issue_flag = TRUE
   OR deprivation_quintile_issue_flag = TRUE
ORDER BY patient_id;