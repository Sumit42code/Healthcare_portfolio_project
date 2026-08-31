/*
Purpose:
Profile primary identifiers in the raw healthcare tables.

Checks:
1. Missing or sentinel identifiers
2. Duplicate identifiers
3. Invalid identifier formats
*/

/*
The first CTE combines the primary identifiers from all six tables into the same structure.
The second CTE standardises identifiers before checking them:
*/

WITH raw_identifiers AS (
    SELECT
        'facilities_raw' AS table_name,
        facility_id AS raw_id
    FROM raw.facilities_raw

    UNION ALL

    SELECT
        'departments_raw',
        department_id
    FROM raw.departments_raw

    UNION ALL

    SELECT
        'patients_raw',
        patient_id
    FROM raw.patients_raw

    UNION ALL

    SELECT
        'referrals_raw',
        referral_id
    FROM raw.referrals_raw

    UNION ALL

    SELECT
        'appointments_raw',
        appointment_id
    FROM raw.appointments_raw

    UNION ALL

    SELECT
        'ed_visits_raw',
        visit_id
    FROM raw.ed_visits_raw
),

normalised_identifiers AS (
    SELECT
        table_name,
        CASE
            WHEN lower(btrim(coalesce(raw_id, '')))
                 IN ('', 'n/a', 'unknown', 'null')
            THEN NULL
            ELSE upper(btrim(raw_id))
        END AS normalised_id
    FROM raw_identifiers
)

SELECT
    table_name,
    count(*) AS total_rows,
    count(*) FILTER (WHERE normalised_id IS NULL)
        AS missing_or_sentinel_ids,
    count(normalised_id) AS non_missing_ids,
    count(DISTINCT normalised_id) AS unique_ids,
    count(normalised_id) - count(DISTINCT normalised_id)
        AS duplicate_excess_rows
FROM normalised_identifiers
GROUP BY
    table_name;

/*List of duplicated identifiers*/

WITH raw_identifiers AS (
    SELECT
        'facilities_raw' AS table_name,
        facility_id AS raw_id
    FROM raw.facilities_raw

    UNION ALL

    SELECT
        'departments_raw',
        department_id
    FROM raw.departments_raw

    UNION ALL

    SELECT
        'patients_raw',
        patient_id
    FROM raw.patients_raw

    UNION ALL

    SELECT
        'referrals_raw',
        referral_id
    FROM raw.referrals_raw

    UNION ALL

    SELECT
        'appointments_raw',
        appointment_id
    FROM raw.appointments_raw

    UNION ALL

    SELECT
        'ed_visits_raw',
        visit_id
    FROM raw.ed_visits_raw
),

normalised_identifiers AS (
    SELECT
        table_name,
        CASE
            WHEN lower(btrim(coalesce(raw_id, '')))
                 IN ('', 'n/a', 'unknown', 'null')
            THEN NULL
            ELSE upper(btrim(raw_id))
        END AS normalised_id
    FROM raw_identifiers
)
SELECT
    table_name,
    normalised_id AS duplicated_id,
    COUNT(*) AS occurrence_count,
    COUNT(*) - 1 AS duplicate_excess_rows

FROM normalised_identifiers

WHERE normalised_id IS NOT NULL

GROUP BY
    table_name,
    normalised_id

HAVING COUNT(*) > 1

ORDER BY
    normalised_id;

/*
Validate identifier formats
*/

with invalid_id_formats AS (

    select
        
        'facilities_raw' AS table_name,
        facility_id AS raw_id,
        'F followed by 3 digits' AS expected_format
    from raw.facilities_raw
    where NULLIF(BTRIM(facility_id), '') IS NOT NULL
      and UPPER(BTRIM(facility_id))
          !~ '^F[0-9]{3}$'

    UNION ALL

    select
        'departments_raw',
        department_id,
        'D followed by 3 digits'
    from raw.departments_raw
    where NULLIF(BTRIM(department_id), '') IS NOT NULL
      and UPPER(BTRIM(department_id))
          !~ '^D[0-9]{3}$'

    UNION ALL

    select
        'patients_raw',
        patient_id,
        'P followed by 6 digits'
    from raw.patients_raw
    where NULLIF(BTRIM(patient_id), '') IS NOT NULL
      and UPPER(BTRIM(patient_id))
          !~ '^P[0-9]{6}$'

    UNION ALL

    select
        'referrals_raw',
        referral_id,
        'R followed by 7 digits'
    from raw.referrals_raw
    where NULLIF(BTRIM(referral_id), '') IS NOT NULL
      and UPPER(BTRIM(referral_id))
          !~ '^R[0-9]{7}$'

    UNION ALL

    SELECT
        'appointments_raw',
        appointment_id,
        'A followed by 7 digits'
    from raw.appointments_raw
    where NULLIF(BTRIM(appointment_id), '') IS NOT NULL
      and UPPER(BTRIM(appointment_id))
          !~ '^A[0-9]{7}$'

    UNION ALL

    select
        'ed_visits_raw',
        visit_id,
        'V followed by 7 digits'
    from raw.ed_visits_raw
    where NULLIF(BTRIM(visit_id), '') IS NOT NULL
      and UPPER(BTRIM(visit_id))
          !~ '^V[0-9]{7}$'

)

select
    table_name,
    raw_id,
    expected_format

from invalid_id_formats

order by
    raw_id;