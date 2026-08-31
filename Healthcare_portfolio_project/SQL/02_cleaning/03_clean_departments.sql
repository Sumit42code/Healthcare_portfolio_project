/*
Purpose:
Create a cleaned department dimension from
raw.departments_raw.

Cleaning rules:
- Trim and standardise identifiers
- Standardise department names
- Standardise specialty groups
- Convert operational targets to INTEGER
- Remove exact duplicates
- Validate facility relationships
- Preserve the original raw table
*/

/*
Exact duplicates
*/
SELECT
    UPPER(BTRIM(department_id)) AS department_id,
    UPPER(BTRIM(facility_id)) AS facility_id,
    LOWER(BTRIM(department_name)) AS department_name,
    LOWER(BTRIM(specialty_group)) AS specialty_group,
    BTRIM(routine_target_days) AS routine_target_days,
    BTRIM(urgent_target_days) AS urgent_target_days,
    BTRIM(appointment_wait_target_mins) AS appointment_wait_target_mins,
    COUNT(*) AS occurrence_count

FROM raw.departments_raw

GROUP BY
    UPPER(BTRIM(department_id)),
    UPPER(BTRIM(facility_id)),
    LOWER(BTRIM(department_name)),
    LOWER(BTRIM(specialty_group)),
    BTRIM(routine_target_days),
    BTRIM(urgent_target_days),
    BTRIM(appointment_wait_target_mins)

HAVING COUNT(*) > 1;

/*
Check facility relationships
Every department should belong to a facility that exists in clean.facilities
*/
SELECT DISTINCT
    d.facility_id as unmatched_facility_id

FROM raw.departments_raw as d

LEFT JOIN clean.facilities as f
    ON UPPER(BTRIM(d.facility_id)) = f.facility_id
WHERE NULLIF(BTRIM(d.facility_id),'') IS NOT NULL
    AND f.facility_id IS NULL;

/*
Create the clean departments table
*/
DROP TABLE IF EXISTS clean.departments;

CREATE TABLE clean.departments (
    department_id VARCHAR(10) PRIMARY KEY,
    facility_id VARCHAR(10) NOT NULL,
    department_name VARCHAR(80) NOT NULL,
    specialty_group VARCHAR(30) NOT NULL,
    routine_target_days INTEGER NOT NULL,
    urgent_target_days INTEGER NOT NULL,
    appointment_wait_target_mins INTEGER NOT NULL,
    CONSTRAINT chk_departments_specialty_group
    CHECK (specialty_group IN ('Medical','Surgical')),

    CONSTRAINT chk_departments_routine_target
    CHECK (routine_target_days > 0),

    CONSTRAINT chk_departments_urgent_target
    CHECK (urgent_target_days > 0),

    CONSTRAINT chk_departments_wait_target
    CHECK (appointment_wait_target_mins > 0),

    CONSTRAINT chk_departments_target_order
    CHECK (urgent_target_days<= routine_target_days)

);

/*
Standardise the department records
*/
WITH standardised_departments AS (
    SELECT
        UPPER(NULLIF(BTRIM(department_id),'')) as department_id,
        UPPER(NULLIF(BTRIM(facility_id),'')) as facility_id,
        CASE    
            WHEN LOWER(BTRIM(department_name)) = 'ent'
            THEN 'ENT'

            ELSE INITCAP(LOWER(NULLIF(BTRIM(department_name),'')))
        END AS department_name,
        INITCAP(LOWER(NULLIF(BTRIM(specialty_group),''))) AS specialty_group,

        CASE
            WHEN BTRIM(COALESCE(routine_target_days,'')) ~ '^[1-9][0-9]*$'
            THEN BTRIM(routine_target_days)::INTEGER
            ELSE NULL
        END AS routine_target_days,

        CASE
            WHEN BTRIM(COALESCE(urgent_target_days,'')) ~ '^[1-9][0-9]*$'
            THEN BTRIM(urgent_target_days)::INTEGER
            ELSE NULL
        END AS urgent_target_days,

        CASE
            WHEN BTRIM(COALESCE(appointment_wait_target_mins,'')) ~ '^[1-9][0-9]*$'
            THEN BTRIM(appointment_wait_target_mins)::INTEGER
            ELSE NULL
        END AS appointment_wait_target_mins
    FROM raw.departments_raw

),
deduplicated_departments AS (
    SELECT DISTINCT
        department_id,
        facility_id,
        department_name,
        specialty_group,
        routine_target_days,
        urgent_target_days,
        appointment_wait_target_mins
    FROM standardised_departments
)

INSERT INTO clean.departments (
    department_id,
    facility_id,
    department_name,
    specialty_group,
    routine_target_days,
    urgent_target_days,
    appointment_wait_target_mins
)
SELECT
    department_id,
    facility_id,
    department_name,
    specialty_group,
    routine_target_days,
    urgent_target_days,
    appointment_wait_target_mins
FROM deduplicated_departments;

/*
Validate row counts
*/
SELECT
    (SELECT COUNT(*)
     FROM raw.departments_raw) AS raw_rows,

    (SELECT COUNT(*)
     FROM clean.departments) AS clean_rows,

    (SELECT COUNT(*)
     FROM raw.departments_raw)
    -
    (SELECT COUNT(*)
     FROM clean.departments) AS removed_rows;

/*
Validate uniqueness
*/

SELECT
    COUNT(*) AS total_rows,
    COUNT(DISTINCT department_id) AS unique_department_ids
FROM clean.departments;

/*
Review cleaned categories
*/
SELECT
    department_name,
    specialty_group,
    COUNT(*) AS department_count
FROM clean.departments
GROUP BY
    department_name,
    specialty_group
ORDER BY
    department_name,
    specialty_group;

/*
Review the final table
*/
SELECT *
FROM clean.departments
ORDER BY department_id;

