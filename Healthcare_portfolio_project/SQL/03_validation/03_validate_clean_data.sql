/*
Validate business consistency between appointments
and their linked referrals.
*/

WITH appointment_referral_checks AS (
    SELECT
        COUNT(*) AS linked_appointment_count,

        COUNT(*) FILTER (
            WHERE appointment.patient_id IS NOT NULL
              AND referral.patient_id IS NOT NULL
              AND appointment.patient_id <>
                  referral.patient_id
        ) AS patient_mismatch_count,

        COUNT(*) FILTER (
            WHERE appointment.department_id IS NOT NULL
              AND referral.department_id IS NOT NULL
              AND appointment.department_id <>
                  referral.department_id
        ) AS department_mismatch_count,

        COUNT(*) FILTER (
            WHERE appointment.scheduled_datetime::DATE <
                  referral.referral_date
        ) AS appointment_before_referral_count

    FROM clean.appointments AS appointment

    INNER JOIN clean.referrals AS referral
        ON appointment.referral_id =
           referral.referral_id
)

SELECT
    linked_appointment_count,
    patient_mismatch_count,
    department_mismatch_count,
    appointment_before_referral_count,

    CASE
        WHEN patient_mismatch_count = 0
         AND department_mismatch_count = 0
         AND appointment_before_referral_count = 0
        THEN 'PASS'
        ELSE 'REVIEW'
    END AS validation_status

FROM appointment_referral_checks;

/*
Purpose:
Confirm that referrals, appointments and ED visits
did not happen before the patient's date of birth.

Patients with a NULL date_of_birth are excluded because
their source birth date was already flagged as unreliable.
*/

WITH patient_timeline_checks AS (
    SELECT
        'Referral before patient birth'
            AS validation_rule,

        COUNT(*) AS issue_count

    FROM clean.referrals AS referral

    INNER JOIN clean.patients AS patient
        ON referral.patient_id =
           patient.patient_id

    WHERE patient.date_of_birth IS NOT NULL
      AND referral.referral_date <
          patient.date_of_birth


    UNION ALL


    SELECT
        'Appointment before patient birth',
        COUNT(*)

    FROM clean.appointments AS appointment

    INNER JOIN clean.patients AS patient
        ON appointment.patient_id =
           patient.patient_id

    WHERE patient.date_of_birth IS NOT NULL
      AND appointment.scheduled_datetime::DATE <
          patient.date_of_birth


    UNION ALL


    SELECT
        'ED visit before patient birth',
        COUNT(*)

    FROM clean.ed_visits AS ed_visit

    INNER JOIN clean.patients AS patient
        ON ed_visit.patient_id =
           patient.patient_id

    WHERE patient.date_of_birth IS NOT NULL
      AND ed_visit.arrival_time::DATE <
          patient.date_of_birth
)

SELECT
    validation_rule,
    issue_count,

    CASE
        WHEN issue_count = 0
        THEN 'PASS'
        ELSE 'REVIEW'
    END AS validation_status

FROM patient_timeline_checks

ORDER BY validation_rule;

/*
Purpose:
Confirm that the planned analytical joins do not
duplicate fact-table records.

This protects Power BI totals from join inflation.
*/

WITH referral_model AS (
    SELECT
        referral.referral_id

    FROM clean.referrals AS referral

    LEFT JOIN clean.patients AS patient
        ON referral.patient_id =
           patient.patient_id

    LEFT JOIN clean.departments AS department
        ON referral.department_id =
           department.department_id
),

appointment_model AS (
    SELECT
        appointment.appointment_id

    FROM clean.appointments AS appointment

    LEFT JOIN clean.patients AS patient
        ON appointment.patient_id =
           patient.patient_id

    LEFT JOIN clean.departments AS department
        ON appointment.department_id =
           department.department_id

    LEFT JOIN clean.referrals AS referral
        ON appointment.referral_id =
           referral.referral_id
),

ed_visit_model AS (
    SELECT
        ed_visit.visit_id

    FROM clean.ed_visits AS ed_visit

    LEFT JOIN clean.patients AS patient
        ON ed_visit.patient_id =
           patient.patient_id

    LEFT JOIN clean.facilities AS facility
        ON ed_visit.facility_id =
           facility.facility_id
),

join_counts AS (
    SELECT
        'Referrals analytical join'
            AS validation_rule,

        (
            SELECT COUNT(*)
            FROM clean.referrals
        ) AS base_row_count,

        (
            SELECT COUNT(*)
            FROM referral_model
        ) AS joined_row_count


    UNION ALL


    SELECT
        'Appointments analytical join',

        (
            SELECT COUNT(*)
            FROM clean.appointments
        ),

        (
            SELECT COUNT(*)
            FROM appointment_model
        )


    UNION ALL


    SELECT
        'ED visits analytical join',

        (
            SELECT COUNT(*)
            FROM clean.ed_visits
        ),

        (
            SELECT COUNT(*)
            FROM ed_visit_model
        )
)

SELECT
    validation_rule,
    base_row_count,
    joined_row_count,

    joined_row_count - base_row_count
        AS unexpected_additional_rows,

    CASE
        WHEN base_row_count = joined_row_count
        THEN 'PASS'
        ELSE 'REVIEW'
    END AS validation_status

FROM join_counts

ORDER BY validation_rule;

/*
Purpose:
Calculate how many records are eligible for important
Power BI healthcare KPIs.

Excluded records are expected because some source-data
issues were intentionally preserved.
*/

WITH metric_readiness AS (
    /*
    Appointment waiting-time KPI
    */
    SELECT
        'Appointment waiting time'
            AS metric_name,

        COUNT(*) FILTER (
            WHERE appointment_status = 'Completed'
        ) AS candidate_records,

        COUNT(*) FILTER (
            WHERE appointment_status = 'Completed'
              AND check_in_time IS NOT NULL
              AND seen_time IS NOT NULL
              AND status_timestamp_issue_flag = FALSE
              AND timeline_issue_flag = FALSE
              AND department_id IS NOT NULL
        ) AS eligible_records

    FROM clean.appointments


    UNION ALL


    /*
    Referral time-to-first-appointment KPI
    */
    SELECT
        'Referral time to first appointment',

        COUNT(*) FILTER (
            WHERE referral_status IN (
                'Completed',
                'Booked'
            )
        ),

        COUNT(*) FILTER (
            WHERE referral_status IN (
                    'Completed',
                    'Booked'
                )
              AND first_appointment_date IS NOT NULL
              AND first_appointment_date >= referral_date
              AND department_id IS NOT NULL
        )

    FROM clean.referrals


    UNION ALL


    /*
    Referral backlog KPI as at the snapshot date
    */
    SELECT
        'Open referral backlog',

        COUNT(*) FILTER (
            WHERE referral_status IN (
                'Open',
                'Waiting'
            )
        ),

        COUNT(*) FILTER (
            WHERE referral_status IN (
                    'Open',
                    'Waiting'
                )
              AND referral_date <= DATE '2026-08-01'
              AND department_id IS NOT NULL
        )

    FROM clean.referrals


    UNION ALL


    /*
    Facility-level ED length-of-stay KPI
    */
    SELECT
        'ED length of stay',

        COUNT(*),

        COUNT(*) FILTER (
            WHERE discharge_time IS NOT NULL
              AND timeline_issue_flag = FALSE
              AND facility_id IS NOT NULL
        )

    FROM clean.ed_visits
)

SELECT
    metric_name,
    candidate_records,
    eligible_records,

    candidate_records - eligible_records
        AS excluded_records,

    ROUND(
        eligible_records * 100.0
        / NULLIF(candidate_records, 0),
        2
    ) AS eligible_percentage

FROM metric_readiness

ORDER BY metric_name;