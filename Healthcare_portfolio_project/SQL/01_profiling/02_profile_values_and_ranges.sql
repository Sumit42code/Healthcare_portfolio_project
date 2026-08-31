/*
Purpose:
Profile important categorical values, missing values,
and formatting inconsistencies in the raw healthcare data.
*/

WITH categorical_values AS (

    /* Facilities */

    SELECT
        'facilities_raw' AS table_name,
        'hospital_region' AS column_name,
        hospital_region AS raw_value
    FROM raw.facilities_raw

    UNION ALL

    SELECT
        'facilities_raw',
        'facility_type',
        facility_type
    FROM raw.facilities_raw

    UNION ALL

    SELECT
        'facilities_raw',
        'city',
        city
    FROM raw.facilities_raw

    /* Departments */

    UNION ALL

    SELECT
        'departments_raw',
        'department_name',
        department_name
    FROM raw.departments_raw

    UNION ALL

    SELECT
        'departments_raw',
        'specialty_group',
        specialty_group
    FROM raw.departments_raw

    /* Patients */

    UNION ALL

    SELECT
        'patients_raw',
        'gender',
        gender
    FROM raw.patients_raw

    UNION ALL

    SELECT
        'patients_raw',
        'city',
        city
    FROM raw.patients_raw

    UNION ALL

    SELECT
        'patients_raw',
        'ethnicity',
        ethnicity
    FROM raw.patients_raw

    /* Referrals */

    UNION ALL

    SELECT
        'referrals_raw',
        'urgency',
        urgency
    FROM raw.referrals_raw

    UNION ALL

    SELECT
        'referrals_raw',
        'referral_status',
        referral_status
    FROM raw.referrals_raw

    UNION ALL

    SELECT
        'referrals_raw',
        'referral_source',
        referral_source
    FROM raw.referrals_raw

    /* Appointments */

    UNION ALL

    SELECT
        'appointments_raw',
        'appointment_status',
        appointment_status
    FROM raw.appointments_raw

    /* ED visits */

    UNION ALL

    SELECT
        'ed_visits_raw',
        'disposition',
        disposition
    FROM raw.ed_visits_raw

    UNION ALL

    SELECT
        'ed_visits_raw',
        'admitted_flag',
        admitted_flag
    FROM raw.ed_visits_raw

)

SELECT
    table_name,
    column_name,

    COALESCE(
        raw_value,
        '[NULL]'
    ) AS original_value,

    CASE
        WHEN NULLIF(BTRIM(raw_value), '') IS NULL
        THEN '[BLANK OR NULL]'

        WHEN LOWER(BTRIM(raw_value))
             IN ('n/a', 'na')
        THEN '[SENTINEL VALUE]'

        ELSE LOWER(BTRIM(raw_value))
    END AS normalised_value,

    COUNT(*) AS record_count

FROM categorical_values

GROUP BY
    table_name,
    column_name,
    raw_value

ORDER BY
    table_name,
    column_name,
    normalised_value,
    original_value;

/*
Check important numeric ranges
*/
--select * from raw.patients_raw;
WITH numeric_checks AS (
    SELECT
        'patients_raw' AS table_name,
        'deprivation_quintile' AS column_name,

        CASE
            WHEN LOWER(BTRIM(COALESCE(deprivation_quintile, ''))) 
                 IN ('', 'n/a', 'unknown', 'null') 
            THEN 'Missing or sentinel value'

            WHEN BTRIM(deprivation_quintile) !~ '^[0-9]+$'
            THEN 'non-numeric value'

            WHEN BTRIM(deprivation_quintile)::integer NOT BETWEEN 1 AND 5
            THEN 'outside range 1-5'

            ELSE NULL
        END AS issue_type
    FROM raw.patients_raw

    UNION ALL

--select * from raw.referrals_raw;
    SELECT
        'referrals_raw',
        'priority_score',
        
        CASE 
            WHEN LOWER(BTRIM(COALESCE(priority_score, ''))) 
                 IN ('', 'n/a', 'na', 'unknown', 'null')
            THEN 'Missing or sentinel value'

            WHEN BTRIM(priority_score) !~ '^[0-9]+$'
            THEN 'non-numeric value'

            WHEN BTRIM(priority_score)::integer NOT BETWEEN 1 AND 5
            THEN 'outside range 1-5'

            ELSE NULL
        END AS issue_type
    FROM raw.referrals_raw

    UNION ALL

--select * from raw.ed_visits_raw;
    SELECT
        'ed_visits_raw',
        'triage_category',

        CASE
            WHEN LOWER(BTRIM(COALESCE(triage_category, ''))) 
                 IN ('', 'n/a', 'na', 'unknown', 'null')
            THEN 'Missing or sentinel value'

            WHEN BTRIM(triage_category) !~ '^[0-9]+$'
            THEN 'non-numeric value'

            WHEN BTRIM(triage_category)::integer NOT BETWEEN 1 AND 5
            THEN 'outside range 1-5'
            
            ELSE NULL
        END AS issue_type
    FROM raw.ed_visits_raw
)

SELECT
    table_name,
    column_name,
    issue_type,
    COUNT(*) AS affected_rows
FROM numeric_checks
WHERE issue_type IS NOT NULL
GROUP BY
    table_name,
    column_name,
    issue_type
ORDER BY
    table_name,
    column_name,
    issue_type;

/*
Check positive operational values
All facility-capacity and departmental-target fields contained 
valid positive whole numbers. No missing, non-numeric, 
zero or negative values were detected
*/

WITH positive_number_checks AS (
    SELECT
        'facilities_raw' AS table_name,
        'bed_capacity' AS column_name,
        bed_capacity::text AS raw_value
    FROM raw.facilities_raw

    UNION ALL

    SELECT
        'departments_raw' AS table_name,
        'routine_target_days' AS column_name,
        routine_target_days::text AS raw_value
    FROM raw.departments_raw

    UNION ALL

    SELECT
        'departments_raw' AS table_name,
        'urgent_target_days' AS column_name,
        urgent_target_days::text AS raw_value
    FROM raw.departments_raw

    UNION ALL

    SELECT
        'departments_raw' AS table_name,
        'appointment_wait_target_mins' AS column_name,
        appointment_wait_target_mins::text AS raw_value
    FROM raw.departments_raw
),

classified_values AS (
    SELECT
        table_name,
        column_name,

        CASE
            WHEN NULLIF(BTRIM(raw_value), '') IS NULL
                THEN 'missing value'

            WHEN BTRIM(raw_value) !~ '^[0-9]+$'
                THEN 'Non numeric value'

            WHEN BTRIM(raw_value)::INTEGER <= 0
                THEN 'Zero or negative value'

            ELSE NULL
        END AS issue_type
    FROM positive_number_checks
)

SELECT
    table_name,
    column_name,
    issue_type,
    COUNT(*) AS affected_rows
FROM classified_values
WHERE issue_type IS NOT NULL
GROUP BY
    table_name,
    column_name,
    issue_type
ORDER BY
    table_name,
    column_name,
    issue_type;

/*

--Check date-of-birth validity

*/

WITH date_of_birth_checks as (
    SELECT patient_id, 
    date_of_birth,

    CASE
        WHEN LOWER(BTRIM(COALESCE(date_of_birth), ''))
        IN('','n/a','na','unknown','null')
        THEN 'Missing or sentinel date'
    
    WHEN NOT PG_INPUT_IS_VALID(BTRIM(date_of_birth),
        'date'
    ) 
    THEN 'Invalid date format'

    WHEN BTRIM(date_of_birth)::DATE < DATE '1900-01-01'
    THEN 'Birth date requires review: before 1900'

    ELSE NULL
    
    END AS issue_type

    FROM raw.patients_raw

)
SELECT 
patient_id,
date_of_birth,
issue_type

FROM date_of_birth_checks

WHERE issue_type IS NOT NULL

ORDER BY
issue_type,
patient_id