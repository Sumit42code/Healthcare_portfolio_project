/*
Purpose:
Clean and standardise appointment records while preserving
important data-quality issues through flags.
*/

/*
Create the clean appointments table
*/
DROP TABLE IF EXISTS clean.appointments;

CREATE TABLE clean.appointments (
    appointment_id VARCHAR(12) PRIMARY KEY,
    patient_id VARCHAR(12),
    department_id VARCHAR(10),
    referral_id VARCHAR(12),
    scheduled_datetime TIMESTAMP NOT NULL,
    check_in_time TIMESTAMP,
    seen_time TIMESTAMP,
    appointment_status VARCHAR(25) NOT NULL,
    appointment_type VARCHAR(50) NOT NULL,
    booking_channel VARCHAR(30) NOT NULL,
    patient_id_issue_flag BOOLEAN NOT NULL,
    department_id_issue_flag BOOLEAN NOT NULL,
    referral_id_issue_flag BOOLEAN NOT NULL,
    status_timestamp_issue_flag BOOLEAN NOT NULL,
    timeline_issue_flag BOOLEAN NOT NULL,

    CONSTRAINT chk_appointment_status
        CHECK (appointment_status IN ('Completed','No Show','Cancelled','Rescheduled','Scheduled')),

    CONSTRAINT chk_appointment_type
        CHECK (appointment_type IN ('First Specialist Assessment','Follow-up','Procedure','Telehealth')),

    CONSTRAINT chk_booking_channel
        CHECK (booking_channel IN ('Referral Team','Phone','Patient Portal','Clinic')),

    CONSTRAINT chk_appointment_timeline
        CHECK (seen_time IS NULL OR check_in_time IS NULL OR seen_time >= check_in_time)
);

/*
Prepare and clean the appointment data
*/
WITH prepared_appointments AS (
    SELECT
        UPPER(NULLIF(BTRIM(appointment_id), '')) AS appointment_id,
        UPPER(NULLIF(BTRIM(patient_id), '')) AS patient_id_lookup,
        UPPER(NULLIF(BTRIM(department_id), '')) AS department_id_lookup,
        UPPER(NULLIF(BTRIM(referral_id), '')) AS referral_id_lookup,
        NULLIF(BTRIM(scheduled_datetime),'')::TIMESTAMP AS scheduled_datetime,
        NULLIF(BTRIM(check_in_time),'')::TIMESTAMP AS check_in_time,
        NULLIF(BTRIM(seen_time),'')::TIMESTAMP AS seen_time,
        LOWER(NULLIF(BTRIM(appointment_status), '')) AS appointment_status_lookup,

        CASE LOWER(NULLIF(BTRIM(appointment_type), ''))
            WHEN 'first specialist assessment'
            THEN 'First Specialist Assessment'

            WHEN 'follow-up'
            THEN 'Follow-up'

            WHEN 'procedure'
            THEN 'Procedure'

            WHEN 'telehealth'
            THEN 'Telehealth'
            ELSE NULL
        END AS appointment_type,

        CASE LOWER(NULLIF(BTRIM(booking_channel), ''))
            WHEN 'referral team'
            THEN 'Referral Team'

            WHEN 'phone'
            THEN 'Phone'

            WHEN 'patient portal'
            THEN 'Patient Portal'

            WHEN 'clinic'
            THEN 'Clinic'
            ELSE NULL
        END AS booking_channel
    FROM raw.appointments_raw
),

standardised_appointments AS (
    SELECT
        appointment.appointment_id,
        patient.patient_id,
        department.department_id,
        referral.referral_id,
        appointment.scheduled_datetime,
        appointment.check_in_time,

        /*
        Remove seen_time when it occurs before check_in_time.
        The original problem is retained through timeline_issue_flag.
        */
        CASE
            WHEN appointment.seen_time IS NULL
            THEN NULL

            WHEN appointment.check_in_time IS NULL
            THEN appointment.seen_time

            WHEN appointment.seen_time >= appointment.check_in_time
            THEN appointment.seen_time

            ELSE NULL
        END AS seen_time,

        status_mapping.standard_value AS appointment_status,

        appointment.appointment_type,
        appointment.booking_channel,

        /*
        Required relationship flags
        */
        (patient.patient_id IS NULL)
            AS patient_id_issue_flag,

        (department.department_id IS NULL)
            AS department_id_issue_flag,

        /*
        Referral ID is optional.

        Blank referral ID:
            referral_id = NULL
            issue flag = FALSE

        Invalid nonblank referral ID:
            referral_id = NULL
            issue flag = TRUE
        */
        (appointment.referral_id_lookup IS NOT NULL
        AND referral.referral_id IS NULL) AS referral_id_issue_flag,

        /*
        A completed appointment should have usable
        check-in and seen timestamps.
        */
        (status_mapping.standard_value = 'Completed'
        AND (appointment.check_in_time IS NULL
        OR appointment.seen_time IS NULL
        OR appointment.seen_time< appointment.check_in_time)
        ) AS status_timestamp_issue_flag,

        /*
        Identify an impossible appointment timeline.
        */
        (appointment.check_in_time IS NOT NULL
        AND appointment.seen_time IS NOT NULL
        AND appointment.seen_time < appointment.check_in_time
        ) AS timeline_issue_flag

    FROM prepared_appointments AS appointment

    LEFT JOIN clean.patients AS patient
        ON appointment.patient_id_lookup =
           patient.patient_id

    LEFT JOIN clean.departments AS department
        ON appointment.department_id_lookup =
           department.department_id

    LEFT JOIN clean.referrals AS referral
        ON appointment.referral_id_lookup =
           referral.referral_id

    LEFT JOIN clean.reference_mappings AS status_mapping
        ON status_mapping.mapping_group =
           'appointment_status'
       AND appointment.appointment_status_lookup =
           status_mapping.raw_value_normalised
),

deduplicated_appointments AS (
    SELECT DISTINCT
        appointment_id,
        patient_id,
        department_id,
        referral_id,
        scheduled_datetime,
        check_in_time,
        seen_time,
        appointment_status,
        appointment_type,
        booking_channel,
        patient_id_issue_flag,
        department_id_issue_flag,
        referral_id_issue_flag,
        status_timestamp_issue_flag,
        timeline_issue_flag

    FROM standardised_appointments
)

INSERT INTO clean.appointments (
    appointment_id,
    patient_id,
    department_id,
    referral_id,
    scheduled_datetime,
    check_in_time,
    seen_time,
    appointment_status,
    appointment_type,
    booking_channel,
    patient_id_issue_flag,
    department_id_issue_flag,
    referral_id_issue_flag,
    status_timestamp_issue_flag,
    timeline_issue_flag
)

SELECT
    appointment_id,
    patient_id,
    department_id,
    referral_id,
    scheduled_datetime,
    check_in_time,
    seen_time,
    appointment_status,
    appointment_type,
    booking_channel,
    patient_id_issue_flag,
    department_id_issue_flag,
    referral_id_issue_flag,
    status_timestamp_issue_flag,
    timeline_issue_flag

FROM deduplicated_appointments;

--Validate the row counts
SELECT
    (SELECT COUNT(*)
     FROM raw.appointments_raw)AS raw_row_count,

    (SELECT COUNT(*)
     FROM clean.appointments)AS clean_row_count,

    (SELECT COUNT(*)
     FROM raw.appointments_raw)
    -
    (SELECT COUNT(*)
     FROM clean.appointments)
        AS duplicate_rows_removed;

--Validate identifiers and required values
SELECT
    COUNT(*) AS total_rows,
    COUNT(DISTINCT appointment_id)AS unique_appointment_ids,

    COUNT(*) FILTER (
        WHERE appointment_id IS NULL) AS missing_appointment_ids,

    COUNT(*) FILTER (
        WHERE scheduled_datetime IS NULL) AS missing_scheduled_datetimes,

    COUNT(*) FILTER (
        WHERE appointment_status IS NULL) AS missing_appointment_statuses,

    COUNT(*) FILTER (
        WHERE appointment_type IS NULL) AS missing_appointment_types,

    COUNT(*) FILTER (
        WHERE booking_channel IS NULL) AS missing_booking_channels

FROM clean.appointments;

--Review the quality flags
SELECT
    COUNT(*) FILTER (
        WHERE patient_id_issue_flag) AS patient_id_issues,

    COUNT(*) FILTER (
        WHERE department_id_issue_flag) AS department_id_issues,

    COUNT(*) FILTER (
        WHERE referral_id_issue_flag) AS referral_id_issues,

    COUNT(*) FILTER (
        WHERE status_timestamp_issue_flag) AS status_timestamp_issues,

    COUNT(*) FILTER (
        WHERE timeline_issue_flag) AS timeline_issues

FROM clean.appointments;

--Confirm no invalid timelines remain
SELECT *
FROM clean.appointments

WHERE check_in_time IS NOT NULL
  AND seen_time IS NOT NULL
  AND seen_time < check_in_time;

--Validate the flags against cleaned values
SELECT *
FROM clean.appointments

WHERE
    (patient_id_issue_flag = TRUE
    AND patient_id IS NOT NULL
    )

    OR (
        patient_id_issue_flag = FALSE
        AND patient_id IS NULL
    )

    OR (
        department_id_issue_flag = TRUE
        AND department_id IS NOT NULL
    )

    OR (
        department_id_issue_flag = FALSE
        AND department_id IS NULL
    )

    OR (
        referral_id_issue_flag = TRUE
        AND referral_id IS NOT NULL
    )

    OR (
        timeline_issue_flag = TRUE
        AND seen_time IS NOT NULL
    )

    OR (
        appointment_status = 'Completed'
        AND status_timestamp_issue_flag = FALSE
        AND (
            check_in_time IS NULL
            OR seen_time IS NULL
        )
    );

/*
Review the standardised categories
*/
SELECT
    appointment_status,
    COUNT(*) AS appointment_count

FROM clean.appointments

GROUP BY appointment_status
ORDER BY appointment_count DESC;


SELECT
    appointment_type,
    COUNT(*) AS appointment_count
FROM clean.appointments
GROUP BY appointment_type
ORDER BY appointment_count DESC;


SELECT
    booking_channel,
    COUNT(*) AS appointment_count

FROM clean.appointments
GROUP BY booking_channel
ORDER BY appointment_count DESC;

SELECT * FROM clean.appointments;