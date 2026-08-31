/*
Purpose:
Create indexes that improve the performance of common
healthcare analytical queries and Power BI data retrieval.

Primary-key columns are not included because PostgreSQL
already creates indexes for primary keys automatically.
*/


/*
Departments
Supports joins between departments and facilities.
*/

CREATE INDEX IF NOT EXISTS idx_departments_facility_id
ON clean.departments (facility_id);


/*
Referrals

Supports:
- viewing a patient's referral history;
- referral analysis by department;
- referral backlog and waiting-time analysis.
*/

CREATE INDEX IF NOT EXISTS idx_referrals_patient_date
ON clean.referrals (patient_id, referral_date);


CREATE INDEX IF NOT EXISTS idx_referrals_department_date
ON clean.referrals (department_id,referral_date);


CREATE INDEX IF NOT EXISTS idx_referrals_status_date
ON clean.referrals (referral_status,referral_date);


/*
Appointments

Supports:
- viewing a patient's appointment history;
- department performance analysis;
- monthly appointment analysis;
- joining appointments to referrals.
*/

CREATE INDEX IF NOT EXISTS idx_appointments_patient_datetime
ON clean.appointments (patient_id, scheduled_datetime);


CREATE INDEX IF NOT EXISTS idx_appointments_department_datetime
ON clean.appointments (department_id, scheduled_datetime);


CREATE INDEX IF NOT EXISTS idx_appointments_referral_id
ON clean.appointments (referral_id);


/*
Emergency department visits

Supports:
- identifying repeat ED visits by patient;
- ED activity analysis by facility;
- date and time-based ED reporting.
*/

CREATE INDEX IF NOT EXISTS idx_ed_visits_patient_arrival
ON clean.ed_visits (patient_id, arrival_time);


CREATE INDEX IF NOT EXISTS idx_ed_visits_facility_arrival
ON clean.ed_visits (facility_id, arrival_time);

CREATE INDEX IF NOT EXISTS idx_referrals_referral_date
    ON clean.referrals (referral_date);


CREATE INDEX IF NOT EXISTS idx_appointments_scheduled_datetime
    ON clean.appointments (scheduled_datetime);


CREATE INDEX IF NOT EXISTS idx_ed_visits_arrival_time
    ON clean.ed_visits (arrival_time);

--Update PostgreSQL table statistics

ANALYZE clean.reference_mappings;
ANALYZE clean.facilities;
ANALYZE clean.departments;
ANALYZE clean.patients;
ANALYZE clean.referrals;
ANALYZE clean.appointments;
ANALYZE clean.ed_visits;

--Verify the indexes
SELECT
    tablename AS table_name,
    indexname AS index_name,
    indexdef AS index_definition
FROM pg_indexes
WHERE schemaname = 'clean'
ORDER BY
    tablename,
    indexname;
