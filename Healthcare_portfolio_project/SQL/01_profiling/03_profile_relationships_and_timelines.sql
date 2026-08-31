/*
Purpose:
Check relationships between raw healthcare tables
and identify impossible event timelines.
*/

/*
Check missing required foreign keys
The purpose is to check whether every child record contains 
the ID needed to connect it to its parent table.
*/
WITH required_foreign_keys AS (

    SELECT
        'departments_raw' AS table_name,
        'facility_id' AS column_name,
        facility_id AS foreign_key_value
    FROM raw.departments_raw

    UNION ALL

    SELECT
        'referrals_raw',
        'patient_id',
        patient_id
    FROM raw.referrals_raw

    UNION ALL

    SELECT
        'referrals_raw',
        'department_id',
        department_id
    FROM raw.referrals_raw

    UNION ALL

    SELECT
        'appointments_raw',
        'patient_id',
        patient_id
    FROM raw.appointments_raw

    UNION ALL

    SELECT
        'appointments_raw',
        'department_id',
        department_id
    FROM raw.appointments_raw

    UNION ALL

    SELECT
        'ed_visits_raw',
        'patient_id',
        patient_id
    FROM raw.ed_visits_raw

    UNION ALL

    SELECT
        'ed_visits_raw',
        'facility_id',
        facility_id
    FROM raw.ed_visits_raw

)

SELECT
    table_name,
    column_name,
    COUNT(*) AS missing_reference_count

FROM required_foreign_keys

WHERE NULLIF(
    BTRIM(foreign_key_value),
    ''
) IS NULL

GROUP BY
    table_name,
    column_name

ORDER BY
    table_name,
    column_name;

/*
Check orphan foreign keys
*/

WITH orphan_relationships AS (

    /* Department must belong to an existing facility */

    SELECT
        'departments_raw' AS child_table,
        'facility_id' AS foreign_key_column,
        'facilities_raw' AS expected_parent_table,
        UPPER(BTRIM(d.facility_id)) AS orphan_id,
        COUNT(*) AS affected_rows

    FROM raw.departments_raw AS d

    WHERE NULLIF(BTRIM(d.facility_id), '') IS NOT NULL

      AND NOT EXISTS (

          SELECT 1
          FROM raw.facilities_raw AS f

          WHERE UPPER(BTRIM(f.facility_id))
                = UPPER(BTRIM(d.facility_id))
      )

    GROUP BY UPPER(BTRIM(d.facility_id))

    UNION ALL

    /* Referral patient must exist */

    SELECT
        'referrals_raw',
        'patient_id',
        'patients_raw',
        UPPER(BTRIM(r.patient_id)),
        COUNT(*)

    FROM raw.referrals_raw AS r

    WHERE NULLIF(BTRIM(r.patient_id), '') IS NOT NULL

      AND NOT EXISTS (

          SELECT 1
          FROM raw.patients_raw AS p

          WHERE UPPER(BTRIM(p.patient_id))
                = UPPER(BTRIM(r.patient_id))
      )

    GROUP BY UPPER(BTRIM(r.patient_id))

    UNION ALL

    /* Referral department must exist */

    SELECT
        'referrals_raw',
        'department_id',
        'departments_raw',
        UPPER(BTRIM(r.department_id)),
        COUNT(*)

    FROM raw.referrals_raw AS r

    WHERE NULLIF(BTRIM(r.department_id), '') IS NOT NULL

      AND NOT EXISTS (

          SELECT 1
          FROM raw.departments_raw AS d

          WHERE UPPER(BTRIM(d.department_id))
                = UPPER(BTRIM(r.department_id))
      )

    GROUP BY UPPER(BTRIM(r.department_id))

    UNION ALL

    /* Appointment patient must exist */

    SELECT
        'appointments_raw',
        'patient_id',
        'patients_raw',
        UPPER(BTRIM(a.patient_id)),
        COUNT(*)

    FROM raw.appointments_raw AS a

    WHERE NULLIF(BTRIM(a.patient_id), '') IS NOT NULL

      AND NOT EXISTS (

          SELECT 1
          FROM raw.patients_raw AS p

          WHERE UPPER(BTRIM(p.patient_id))
                = UPPER(BTRIM(a.patient_id))
      )

    GROUP BY UPPER(BTRIM(a.patient_id))

    UNION ALL

    /* Appointment department must exist */

    SELECT
        'appointments_raw',
        'department_id',
        'departments_raw',
        UPPER(BTRIM(a.department_id)),
        COUNT(*)

    FROM raw.appointments_raw AS a

    WHERE NULLIF(BTRIM(a.department_id), '') IS NOT NULL

      AND NOT EXISTS (

          SELECT 1
          FROM raw.departments_raw AS d

          WHERE UPPER(BTRIM(d.department_id))
                = UPPER(BTRIM(a.department_id))
      )

    GROUP BY UPPER(BTRIM(a.department_id))

    UNION ALL

    /* Non-blank appointment referral must exist */

    SELECT
        'appointments_raw',
        'referral_id',
        'referrals_raw',
        UPPER(BTRIM(a.referral_id)),
        COUNT(*)

    FROM raw.appointments_raw AS a

    WHERE NULLIF(BTRIM(a.referral_id), '') IS NOT NULL

      AND NOT EXISTS (

          SELECT 1
          FROM raw.referrals_raw AS r

          WHERE UPPER(BTRIM(r.referral_id))
                = UPPER(BTRIM(a.referral_id))
      )

    GROUP BY UPPER(BTRIM(a.referral_id))

    UNION ALL

    /* ED patient must exist */

    SELECT
        'ed_visits_raw',
        'patient_id',
        'patients_raw',
        UPPER(BTRIM(e.patient_id)),
        COUNT(*)

    FROM raw.ed_visits_raw AS e

    WHERE NULLIF(BTRIM(e.patient_id), '') IS NOT NULL

      AND NOT EXISTS (

          SELECT 1
          FROM raw.patients_raw AS p

          WHERE UPPER(BTRIM(p.patient_id))
                = UPPER(BTRIM(e.patient_id))
      )

    GROUP BY UPPER(BTRIM(e.patient_id))

    UNION ALL

    /* ED facility must exist */

    SELECT
        'ed_visits_raw',
        'facility_id',
        'facilities_raw',
        UPPER(BTRIM(e.facility_id)),
        COUNT(*)

    FROM raw.ed_visits_raw AS e

    WHERE NULLIF(BTRIM(e.facility_id), '') IS NOT NULL

      AND NOT EXISTS (

          SELECT 1
          FROM raw.facilities_raw AS f

          WHERE UPPER(BTRIM(f.facility_id))
                = UPPER(BTRIM(e.facility_id))
      )

    GROUP BY UPPER(BTRIM(e.facility_id))

)

SELECT
    child_table,
    foreign_key_column,
    expected_parent_table,
    orphan_id,
    affected_rows

FROM orphan_relationships

ORDER BY
    child_table,
    foreign_key_column,
    orphan_id;


/*
Check impossible timelines
The purpose of checking impossible timelines is to 
confirm that healthcare events happened in a logical 
chronological order.
*/
WITH timeline_issues AS (

    /* A patient cannot enrol before being born */

    SELECT
        'patients_raw' AS table_name,
        patient_id AS record_id,
        'Enrolment before date of birth' AS issue_type,
        date_of_birth AS earlier_event,
        enrolment_date AS later_event

    FROM raw.patients_raw

    WHERE NULLIF(BTRIM(date_of_birth), '') IS NOT NULL
      AND NULLIF(BTRIM(enrolment_date), '') IS NOT NULL
      AND BTRIM(enrolment_date)::DATE < BTRIM(date_of_birth)::DATE

    UNION ALL

    /* First appointment cannot occur before referral */

    SELECT
        'referrals_raw',
        referral_id,
        'First appointment before referral',
        referral_date,
        first_appointment_date
    FROM raw.referrals_raw

    WHERE NULLIF(BTRIM(referral_date), '') IS NOT NULL
      AND NULLIF(BTRIM(first_appointment_date), '') IS NOT NULL
      AND BTRIM(first_appointment_date)::DATE < BTRIM(referral_date)::DATE

    UNION ALL

    /* Referral cannot close before it was received */

    SELECT
        'referrals_raw',
        referral_id,
        'Referral closed before referral date',
        referral_date,
        closed_date

    FROM raw.referrals_raw

    WHERE NULLIF(BTRIM(referral_date), '') IS NOT NULL
      AND NULLIF(BTRIM(closed_date), '') IS NOT NULL AND BTRIM(closed_date)::DATE
          < BTRIM(referral_date)::DATE

    UNION ALL

    /* Patient cannot be seen before checking in */

    SELECT
        'appointments_raw',
        appointment_id,
        'Seen time before check-in time',
        check_in_time,
        seen_time

    FROM raw.appointments_raw

    WHERE NULLIF(BTRIM(check_in_time), '') IS NOT NULL
      AND NULLIF(BTRIM(seen_time), '') IS NOT NULL
      AND BTRIM(seen_time)::TIMESTAMP < BTRIM(check_in_time)::TIMESTAMP

    UNION ALL

    /* ED discharge cannot occur before ED arrival */

    SELECT
        'ed_visits_raw',
        visit_id,
        'Discharge before arrival',
        arrival_time,
        discharge_time

    FROM raw.ed_visits_raw

    WHERE NULLIF(BTRIM(arrival_time), '') IS NOT NULL
      AND NULLIF(BTRIM(discharge_time), '') IS NOT NULL
      AND BTRIM(discharge_time)::TIMESTAMP < BTRIM(arrival_time)::TIMESTAMP

)

SELECT
    table_name,
    issue_type,
    COUNT(*) AS affected_rows,
    COUNT(DISTINCT record_id) AS affected_unique_records

FROM timeline_issues

GROUP BY
    table_name,
    issue_type

ORDER BY
    table_name,
    issue_type;

/*
Check status and timestamp consistency
The purpose of status and timestamp consistency is 
to check whether a record’s status agrees with its 
supporting timestamps.
*/

WITH consistency_issues AS (

    SELECT
        'appointments_raw' AS table_name,
        appointment_id AS record_id,
        'Completed appointment missing check-in time' AS issue_type

    FROM raw.appointments_raw

    WHERE LOWER(BTRIM(appointment_status)) = 'completed'
      AND NULLIF(BTRIM(check_in_time), '') IS NULL

    UNION ALL

    SELECT
        'appointments_raw',
        appointment_id,
        'Completed appointment missing seen time'

    FROM raw.appointments_raw

    WHERE LOWER(BTRIM(appointment_status)) = 'completed'
      AND NULLIF(BTRIM(seen_time), '') IS NULL

    UNION ALL

    SELECT
        'ed_visits_raw',
        visit_id,
        'Disposition recorded but discharge time missing'

    FROM raw.ed_visits_raw

    WHERE NULLIF(BTRIM(disposition), '') IS NOT NULL
      AND NULLIF(BTRIM(discharge_time), '') IS NULL

)

SELECT
    table_name,
    issue_type,
    COUNT(*) AS affected_rows,
    COUNT(DISTINCT record_id) AS affected_unique_records

FROM consistency_issues

GROUP BY
    table_name,
    issue_type

ORDER BY
    table_name,
    issue_type;