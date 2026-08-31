/*
Purpose:
Answer common healthcare business questions using the
analysis-ready views.

Analysis areas:
1. Referral demand and backlog
2. Appointment performance
3. Emergency department flow
*/


/* SECTION 1: REFERRAL ANALYSIS */


/*
Business Question 1:
How is referral volume changing each month and by status?
*/

SELECT
    DATE_TRUNC('month',referral_date)::DATE AS referral_month,
    referral_status,
    COUNT(*) AS total_referrals
FROM analytics.vw_referral_analysis

GROUP BY DATE_TRUNC('month',referral_date)::DATE,
        referral_status
ORDER BY
    referral_month,
    referral_status;


/*
Business Question 2:
Which departments have the largest referral backlog?
*/

SELECT
    hospital_region,
    facility_name,
    department_name,
    COUNT(*) AS total_backlog,
    ROUND(AVG(backlog_wait_days),2) AS average_wait_days,

    COUNT(*) FILTER (
        WHERE backlog_over_target_flag IS NOT NULL) AS target_eligible_referrals,

    COUNT(*) FILTER (
        WHERE backlog_over_target_flag = TRUE) AS referrals_over_target,

    ROUND(
        COUNT(*) FILTER (WHERE backlog_over_target_flag = TRUE) * 100.0
        / 
        NULLIF(COUNT(*) FILTER (WHERE backlog_over_target_flag IS NOT NULL),0),2) AS over_target_percentage
FROM analytics.vw_referral_analysis

WHERE backlog_flag = TRUE

GROUP BY
    hospital_region,
    facility_name,
    department_name

ORDER BY
    total_backlog DESC;


/*
Business Question 3:
How is the referral backlog distributed across
different waiting-time bands?
*/

SELECT
    hospital_region,
    backlog_wait_band,
    COUNT(*) AS referral_count
FROM analytics.vw_referral_analysis
WHERE backlog_flag = TRUE
GROUP BY
    hospital_region,
    backlog_wait_band
ORDER BY
    hospital_region,
    CASE backlog_wait_band
        WHEN '0-14 days' THEN 1
        WHEN '15-30 days' THEN 2
        WHEN '31-60 days' THEN 3
        WHEN 'Over 60 days' THEN 4
    END;



/*
Business Question 4:
What percentage of referrals received their first
appointment within the target?
*/

SELECT
    hospital_region,
    urgency,
    COUNT(*) AS referrals_with_known_target,
    ROUND(AVG(days_to_first_appointment),2) AS average_days_to_first_appointment,
    COUNT(*) FILTER (WHERE first_appointment_met_target_flag = TRUE) AS referrals_within_target,

    ROUND(COUNT(*) FILTER (WHERE first_appointment_met_target_flag = TRUE) * 100.0
    / 
    NULLIF(COUNT(*), 0),2) AS target_met_percentage

FROM analytics.vw_referral_analysis

WHERE first_appointment_met_target_flag IS NOT NULL
GROUP BY
    hospital_region,
    urgency
ORDER BY
    hospital_region,
    urgency;


/*
SECTION 2: APPOINTMENT ANALYSIS
*/


/*
Business Question 5:
How many appointments occurred each month by status?
*/

SELECT
    scheduled_month,
    appointment_status,
    COUNT(*) AS appointment_count
FROM analytics.vw_appointment_analysis
GROUP BY
    scheduled_month,
    appointment_status
ORDER BY
    scheduled_month,
    appointment_status;


/*
Business Question 6:
Which departments have the highest appointment
no-show rates?
*/

SELECT
    hospital_region,
    facility_name,
    department_name,
    COUNT(*) AS eligible_appointments,

    COUNT(*) FILTER (WHERE no_show_flag = TRUE) AS no_show_appointments,

    ROUND(COUNT(*) FILTER (WHERE no_show_flag = TRUE) * 100.0
    / 
    NULLIF(COUNT(*), 0),2) AS no_show_rate_percentage

FROM analytics.vw_appointment_analysis

WHERE attendance_eligible_flag = TRUE

GROUP BY
    hospital_region,
    facility_name,
    department_name

ORDER BY
    no_show_rate_percentage DESC;


/*
Business Question 7:
Which departments are meeting their appointment
waiting-time targets?
*/

SELECT
    hospital_region,
    facility_name,
    department_name,

    COUNT(*) AS appointments_with_wait_time,

    ROUND(AVG(waiting_minutes),2) AS average_waiting_minutes,

    COUNT(*) FILTER (WHERE met_wait_target_flag IS NOT NULL) AS target_eligible_appointments,

    COUNT(*) FILTER (WHERE met_wait_target_flag = TRUE) AS appointments_within_target,

    ROUND(COUNT(*) FILTER (WHERE met_wait_target_flag = TRUE) * 100.0
    / 
    NULLIF(COUNT(*) FILTER (WHERE met_wait_target_flag IS NOT NULL),0),2) AS target_met_percentage

FROM analytics.vw_appointment_analysis

WHERE wait_time_eligible_flag = TRUE

GROUP BY
    hospital_region,
    facility_name,
    department_name
ORDER BY
    target_met_percentage;


/*
Business Question 8:
Does the appointment no-show rate differ by booking channel?
*/

SELECT
    booking_channel,

    COUNT(*) AS eligible_appointments,

    COUNT(*) FILTER (WHERE no_show_flag = TRUE) AS no_show_appointments,

    ROUND(COUNT(*) FILTER (WHERE no_show_flag = TRUE) * 100.0
    /
    NULLIF(COUNT(*), 0),2) AS no_show_rate_percentage

FROM analytics.vw_appointment_analysis

WHERE attendance_eligible_flag = TRUE

GROUP BY
    booking_channel

ORDER BY
    no_show_rate_percentage DESC;


/*
Business Question 9:
Does the no-show rate differ by patient deprivation quintile?
*/

SELECT
    deprivation_quintile,

    COUNT(*) AS eligible_appointments,

    COUNT(*) FILTER (WHERE no_show_flag = TRUE) AS no_show_appointments,

    ROUND(COUNT(*) FILTER (WHERE no_show_flag = TRUE) * 100.0
    / 
    NULLIF(COUNT(*), 0),2) AS no_show_rate_percentage

FROM analytics.vw_appointment_analysis

WHERE attendance_eligible_flag = TRUE
AND deprivation_quintile IS NOT NULL

GROUP BY
deprivation_quintile

ORDER BY
deprivation_quintile;


/*
SECTION 3: EMERGENCY DEPARTMENT ANALYSIS
*/


/*
Business Question 10:
How is emergency department demand changing
each month?
*/

SELECT
    arrival_month,
    hospital_region,
    COUNT(*) AS total_ed_visits
FROM analytics.vw_ed_visit_analysis
GROUP BY
    arrival_month,
    hospital_region
ORDER BY
    arrival_month,
    hospital_region;


/*
Business Question 11:
Which facilities have the longest average
emergency department stays?
*/

SELECT
    hospital_region,
    facility_name,
    COUNT(*) AS eligible_ed_visits,
    ROUND(AVG(length_of_stay_hours),2) AS average_length_of_stay_hours,
    ROUND(MAX(length_of_stay_hours),2) AS longest_length_of_stay_hours
FROM analytics.vw_ed_visit_analysis
WHERE length_of_stay_eligible_flag = TRUE

GROUP BY
    hospital_region,
    facility_name

ORDER BY
    average_length_of_stay_hours DESC;


/*
Business Question 12:
What percentage of ED visits resulted in admission
or the patient leaving before treatment?
*/

SELECT
    hospital_region,
    facility_name,
    COUNT(*) AS total_ed_visits,
    COUNT(*) FILTER (WHERE admitted_flag = TRUE) AS admitted_visits,

    ROUND(COUNT(*) FILTER (WHERE admitted_flag = TRUE) * 100.0
    / 
    NULLIF(COUNT(*), 0),2) AS admission_rate_percentage,

    COUNT(*) FILTER (WHERE left_before_treatment_flag = TRUE) AS left_before_treatment_visits,

    ROUND(COUNT(*) FILTER (WHERE left_before_treatment_flag = TRUE) * 100.0
    /
    NULLIF(COUNT(*), 0),2) AS left_before_treatment_percentage
FROM analytics.vw_ed_visit_analysis

GROUP BY
    hospital_region,
    facility_name

ORDER BY
    total_ed_visits DESC;


/*
Business Question 13:
What are the most common reasons patients visit
the emergency department?
*/

SELECT
    presenting_group,
    COUNT(*) AS total_ed_visits,

    ROUND(COUNT(*) * 100.0
    / 
    SUM(COUNT(*)) OVER (),2) AS percentage_of_ed_visits
FROM analytics.vw_ed_visit_analysis
GROUP BY
presenting_group

ORDER BY
total_ed_visits DESC;





/*
Business Question 14:
How many ED visits occurred within seven days of the
patient's previous ED discharge?

This query demonstrates a CTE and the LAG window function.
It measures repeat ED visits, not hospital readmissions.
*/

WITH patient_visit_history AS (
    SELECT
        visit_id,
        patient_id,
        facility_name,
        arrival_time,
        discharge_time,

        LAG(discharge_time) OVER (PARTITION BY patient_id
        ORDER BY arrival_time) AS previous_discharge_time

    FROM analytics.vw_ed_visit_analysis

    WHERE patient_id IS NOT NULL
)

SELECT
    facility_name,
    COUNT(*) FILTER (
    WHERE previous_discharge_time IS NOT NULL) AS visits_with_previous_discharge,

    COUNT(*) FILTER (
        WHERE arrival_time > previous_discharge_time
        AND arrival_time <= previous_discharge_time + INTERVAL '7 days'
    ) AS return_visits_within_7_days,

    ROUND(COUNT(*) FILTER (WHERE arrival_time > previous_discharge_time
    AND arrival_time <= previous_discharge_time + INTERVAL '7 days') * 100.0
    / 
    NULLIF(COUNT(*) FILTER (WHERE previous_discharge_time IS NOT NULL),0),2) AS seven_day_return_percentage
FROM patient_visit_history

GROUP BY facility_name

ORDER BY seven_day_return_percentage DESC;

