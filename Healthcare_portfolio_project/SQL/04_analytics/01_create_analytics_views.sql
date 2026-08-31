/*
Purpose:
Create analysis ready views for the healthcare dashboard.

View grain:
- vw_referral_analysis: one row per referral
- vw_appointment_analysis: one row per appointment
- vw_ed_visit_analysis: one row per ED visit
*/


BEGIN;


CREATE SCHEMA IF NOT EXISTS analytics;


/* 
REFERRAL ANALYSIS
*/
select * from analytics.vw_referral_analysis;

CREATE OR REPLACE VIEW analytics.vw_referral_analysis AS

WITH referral_base AS (
    SELECT
        r.referral_id,
        r.patient_id,
        r.department_id,
        d.facility_id,
        f.facility_name,
        f.hospital_region,
        f.city AS facility_city,
        d.department_name,
        d.specialty_group,
        r.referral_date,
        r.urgency,
        r.referral_status,
        r.referral_source,
        r.priority_score,
        r.first_appointment_date,
        r.closed_date,
        p.date_of_birth,
        p.gender,
        p.ethnicity,
        p.city AS patient_city,
        p.deprivation_quintile,

/*
The department table contains targets only for Routine and Urgent referrals.
*/
CASE
    WHEN r.urgency = 'Urgent'
    THEN d.urgent_target_days

    WHEN r.urgency = 'Routine'
    THEN d.routine_target_days

    ELSE NULL
    END AS target_days

    FROM clean.referrals AS r

    LEFT JOIN clean.patients AS p
    ON r.patient_id = p.patient_id

    LEFT JOIN clean.departments AS d
    ON r.department_id = d.department_id

    LEFT JOIN clean.facilities AS f
    ON d.facility_id = f.facility_id
)

SELECT
    referral_id,
    patient_id,
    department_id,
    facility_id,
    facility_name,
    hospital_region,
    facility_city,
    department_name,
    specialty_group,
    referral_date,
    urgency,
    referral_status,
    referral_source,
    priority_score,
    first_appointment_date,
    closed_date,
    date_of_birth,
    gender,
    ethnicity,
    patient_city,
    deprivation_quintile,
    target_days,

/*
Time from referral to first appointment.
*/
    CASE
        WHEN first_appointment_date IS NOT NULL
        THEN first_appointment_date - referral_date
        ELSE NULL
    END AS days_to_first_appointment,

/*
Determine whether the first appointment met the relevant referral target.
*/
    CASE
        WHEN first_appointment_date IS NULL
        OR target_days IS NULL
        THEN NULL
        ELSE
            first_appointment_date - referral_date <= target_days
    END AS first_appointment_met_target_flag,

/*
Backlog includes Open and Waiting referrals.
*/
    referral_status IN ('Open', 'Waiting') AS backlog_flag,

    DATE '2026-08-01' AS snapshot_date,

/*
Current waiting time is calculated only for referrals included in the backlog.
*/
    CASE
        WHEN referral_status IN ('Open', 'Waiting')
        THEN DATE '2026-08-01' - referral_date
        ELSE NULL
    END AS backlog_wait_days,

/*
Create understandable waiting-time groups for charts and dashboard filters.
*/
    CASE
        WHEN referral_status 
        NOT IN ('Open', 'Waiting')
        THEN NULL

        WHEN DATE '2026-08-01' - referral_date
        BETWEEN 0 AND 14
        THEN '0-14 days'

        WHEN DATE '2026-08-01' - referral_date
        BETWEEN 15 AND 30
        THEN '15-30 days'

        WHEN DATE '2026-08-01' - referral_date
        BETWEEN 31 AND 60
        THEN '31-60 days'

        ELSE 'Over 60 days'
    END AS backlog_wait_band,

/*
NULL means that a target was not available.
*/
    CASE
        WHEN referral_status 
        NOT IN ('Open', 'Waiting')
        OR target_days IS NULL
        THEN NULL

        ELSE
        DATE '2026-08-01' - referral_date > target_days
    END AS backlog_over_target_flag
    FROM referral_base;


/*
APPOINTMENT ANALYSIS
*/
SELECT * FROM analytics.vw_appointment_analysis;
CREATE OR REPLACE VIEW analytics.vw_appointment_analysis AS

WITH appointment_base AS (
    SELECT
        a.appointment_id,
        a.referral_id,
        a.patient_id,
        a.department_id,
        d.facility_id,
        f.facility_name,
        f.hospital_region,
        f.city AS facility_city,
        d.department_name,
        d.specialty_group,
        d.appointment_wait_target_mins,
        a.scheduled_datetime,
        a.check_in_time,
        a.seen_time,
        a.appointment_status,
        a.appointment_type,
        a.booking_channel,
        p.gender,
        p.ethnicity,
        p.city AS patient_city,
        p.deprivation_quintile,

        /*
        Waiting time is calculated only when the
        timestamps are valid.
        */
        CASE
            WHEN a.appointment_status = 'Completed'
             AND a.check_in_time IS NOT NULL
             AND a.seen_time IS NOT NULL
             AND COALESCE(a.status_timestamp_issue_flag, FALSE) = FALSE
             AND COALESCE(a.timeline_issue_flag, FALSE) = FALSE

            THEN ROUND(EXTRACT(EPOCH FROM (a.seen_time - a.check_in_time)) / 60.0,2)
            ELSE NULL           
        END AS waiting_minutes,

        a.patient_id_issue_flag,
        a.department_id_issue_flag,
        a.referral_id_issue_flag,
        a.status_timestamp_issue_flag,
        a.timeline_issue_flag

    FROM clean.appointments AS a

    LEFT JOIN clean.patients AS p
        ON a.patient_id = p.patient_id

    LEFT JOIN clean.departments AS d
        ON a.department_id = d.department_id

    LEFT JOIN clean.facilities AS f
        ON d.facility_id = f.facility_id
)

SELECT
    appointment_id,
    referral_id,
    patient_id,
    department_id,
    facility_id,
    facility_name,
    hospital_region,
    facility_city,
    department_name,
    specialty_group,
    scheduled_datetime,
    scheduled_datetime::DATE AS scheduled_date,
    DATE_TRUNC('month', scheduled_datetime)::DATE AS scheduled_month,
    check_in_time,
    seen_time,
    appointment_status,
    appointment_type,
    booking_channel,
    gender,
    ethnicity,
    patient_city,
    deprivation_quintile,
    appointment_wait_target_mins,
    waiting_minutes,
    /*
    Completed and No Show appointments are suitable
    for attendance-rate calculations.
    */
    appointment_status IN ('Completed','No Show') AS attendance_eligible_flag,

    appointment_status = 'Completed'AS completed_flag,

    appointment_status = 'No Show' AS no_show_flag,

    waiting_minutes IS NOT NULL AS wait_time_eligible_flag,

    /*
    NULL means that the waiting time or target
    was unavailable.
    */
    CASE
        WHEN waiting_minutes IS NULL
        OR appointment_wait_target_mins IS NULL
        THEN NULL
        ELSE
            waiting_minutes <= appointment_wait_target_mins
    END AS met_wait_target_flag,

    patient_id_issue_flag,
    department_id_issue_flag,
    referral_id_issue_flag,
    status_timestamp_issue_flag,
    timeline_issue_flag

FROM appointment_base;


/* 
EMERGENCY DEPARTMENT VISIT ANALYSIS
*/

select * from analytics.vw_ed_visit_analysis;

CREATE OR REPLACE VIEW analytics.vw_ed_visit_analysis AS

WITH ed_visit_base AS (
    SELECT
        e.visit_id,
        e.patient_id,
        e.facility_id,
        f.facility_name,
        f.hospital_region,
        f.city AS facility_city,
        f.facility_type,

        e.arrival_time,
        e.discharge_time,
        e.triage_category,
        e.disposition,
        e.admitted_flag,
        e.presenting_group,

        p.gender,
        p.ethnicity,
        p.city AS patient_city,
        p.deprivation_quintile,

        /*
        Calculate length of stay only when the
        discharge timestamp is available and valid.
        */
        CASE
            WHEN e.discharge_time IS NOT NULL
            AND COALESCE(e.timeline_issue_flag, FALSE) = FALSE
            THEN ROUND(EXTRACT(EPOCH FROM (e.discharge_time - e.arrival_time)) / 3600.0,2)
            ELSE NULL
        END AS length_of_stay_hours,

        e.patient_id_issue_flag,
        e.facility_id_issue_flag,
        e.triage_category_issue_flag,
        e.missing_discharge_time_flag,
        e.timeline_issue_flag,
        e.admission_consistency_issue_flag
    FROM clean.ed_visits AS e

    LEFT JOIN clean.patients AS p
        ON e.patient_id = p.patient_id

    LEFT JOIN clean.facilities AS f
        ON e.facility_id = f.facility_id
)

SELECT
    visit_id,
    patient_id,
    facility_id,
    facility_name,
    hospital_region,
    facility_city,
    facility_type,
    arrival_time,
    arrival_time::DATE AS arrival_date,
    DATE_TRUNC('month',arrival_time)::DATE AS arrival_month,
    discharge_time,
    triage_category,
    disposition,
    admitted_flag,
    presenting_group,
    gender,
    ethnicity,
    patient_city,
    deprivation_quintile,
    length_of_stay_hours,
    length_of_stay_hours IS NOT NULL AS length_of_stay_eligible_flag,
    disposition = 'Left Before Treatment' AS left_before_treatment_flag,
    patient_id_issue_flag,
    facility_id_issue_flag,
    triage_category_issue_flag,
    missing_discharge_time_flag,
    timeline_issue_flag,
    admission_consistency_issue_flag

FROM ed_visit_base;


COMMIT;