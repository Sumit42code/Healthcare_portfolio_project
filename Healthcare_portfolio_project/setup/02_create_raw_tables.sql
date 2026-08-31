/*
Purpose:
Create raw tables that preserve the imported CSV data
without cleaning, converting or removing records.
*/


-- 1. Facilities

CREATE TABLE IF NOT EXISTS raw.facilities_raw (
    facility_id TEXT,
    facility_name TEXT,
    hospital_region TEXT,
    city TEXT,
    facility_type TEXT,
    bed_capacity TEXT
);


-- 2. Departments

CREATE TABLE IF NOT EXISTS raw.departments_raw (
    department_id TEXT,
    facility_id TEXT,
    department_name TEXT,
    specialty_group TEXT,
    routine_target_days TEXT,
    urgent_target_days TEXT,
    appointment_wait_target_mins TEXT
);


-- 3. Patients

CREATE TABLE IF NOT EXISTS raw.patients_raw (
    patient_id TEXT,
    date_of_birth TEXT,
    gender TEXT,
    ethnicity TEXT,
    city TEXT,
    deprivation_quintile TEXT,
    enrolment_date TEXT
);


-- 4. Referrals

CREATE TABLE IF NOT EXISTS raw.referrals_raw (
    referral_id TEXT,
    patient_id TEXT,
    department_id TEXT,
    referral_date TEXT,
    urgency TEXT,
    referral_status TEXT,
    first_appointment_date TEXT,
    closed_date TEXT,
    referral_source TEXT,
    priority_score TEXT
);


-- 5. Appointments

CREATE TABLE IF NOT EXISTS raw.appointments_raw (
    appointment_id TEXT,
    patient_id TEXT,
    department_id TEXT,
    referral_id TEXT,
    scheduled_datetime TEXT,
    check_in_time TEXT,
    seen_time TEXT,
    appointment_status TEXT,
    appointment_type TEXT,
    booking_channel TEXT
);


-- 6. Emergency department visits

CREATE TABLE IF NOT EXISTS raw.ed_visits_raw (
    visit_id TEXT,
    patient_id TEXT,
    facility_id TEXT,
    arrival_time TEXT,
    triage_category TEXT,
    discharge_time TEXT,
    disposition TEXT,
    admitted_flag TEXT,
    presenting_group TEXT
);

--Vslidate table name
SELECT
    table_schema,
    table_name
FROM information_schema.tables
WHERE table_schema = 'raw'
ORDER BY table_name;