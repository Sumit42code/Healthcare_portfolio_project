/*
Purpose:
Confirm that every non-null foreign-key value in the clean tables
has a matching parent record before adding foreign-key constraints.

Every orphan_count should be 0.
*/

--Check relationships before adding constraints

BEGIN;
SELECT
    'departments → facilities' AS relationship,
    COUNT(*) AS orphan_count
FROM clean.departments AS department

LEFT JOIN clean.facilities AS facility
    ON department.facility_id = facility.facility_id

WHERE department.facility_id IS NOT NULL
  AND facility.facility_id IS NULL


UNION ALL


SELECT
    'referrals → patients',
    COUNT(*)
FROM clean.referrals AS referral

LEFT JOIN clean.patients AS patient
    ON referral.patient_id = patient.patient_id

WHERE referral.patient_id IS NOT NULL
  AND patient.patient_id IS NULL


UNION ALL


SELECT
    'referrals → departments',
    COUNT(*)

FROM clean.referrals AS referral

LEFT JOIN clean.departments AS department
    ON referral.department_id = department.department_id

WHERE referral.department_id IS NOT NULL
  AND department.department_id IS NULL


UNION ALL


SELECT
    'appointments → patients',
    COUNT(*)

FROM clean.appointments AS appointment

LEFT JOIN clean.patients AS patient
    ON appointment.patient_id = patient.patient_id

WHERE appointment.patient_id IS NOT NULL
  AND patient.patient_id IS NULL


UNION ALL


SELECT
    'appointments → departments',
    COUNT(*)

FROM clean.appointments AS appointment

LEFT JOIN clean.departments AS department
    ON appointment.department_id = department.department_id

WHERE appointment.department_id IS NOT NULL
  AND department.department_id IS NULL


UNION ALL


SELECT
    'appointments → referrals',
    COUNT(*)

FROM clean.appointments AS appointment

LEFT JOIN clean.referrals AS referral
    ON appointment.referral_id = referral.referral_id

WHERE appointment.referral_id IS NOT NULL
  AND referral.referral_id IS NULL


UNION ALL


SELECT
    'ed_visits → patients',
    COUNT(*)

FROM clean.ed_visits AS ed_visit

LEFT JOIN clean.patients AS patient
    ON ed_visit.patient_id = patient.patient_id

WHERE ed_visit.patient_id IS NOT NULL
  AND patient.patient_id IS NULL


UNION ALL


SELECT
    'ed_visits → facilities',
    COUNT(*)

FROM clean.ed_visits AS ed_visit

LEFT JOIN clean.facilities AS facility
    ON ed_visit.facility_id = facility.facility_id

WHERE ed_visit.facility_id IS NOT NULL
  AND facility.facility_id IS NULL;

/*
Add the foreign-key constraints
*/

/*
Departments must reference an existing facility.
*/

ALTER TABLE clean.departments
    DROP CONSTRAINT IF EXISTS fk_departments_facility;

ALTER TABLE clean.departments
    ADD CONSTRAINT fk_departments_facility
    FOREIGN KEY (facility_id)
    REFERENCES clean.facilities (facility_id);

/*
Referrals may reference patients and departments.
*/

ALTER TABLE clean.referrals
    DROP CONSTRAINT IF EXISTS fk_referrals_patient;

ALTER TABLE clean.referrals
    ADD CONSTRAINT fk_referrals_patient
    FOREIGN KEY (patient_id)
    REFERENCES clean.patients (patient_id);

ALTER TABLE clean.referrals
    DROP CONSTRAINT IF EXISTS fk_referrals_department;

ALTER TABLE clean.referrals
    ADD CONSTRAINT fk_referrals_department
    FOREIGN KEY (department_id)
    REFERENCES clean.departments (department_id);

/*
Appointments may reference patients, departments
and optional referrals.
*/

ALTER TABLE clean.appointments
    DROP CONSTRAINT IF EXISTS fk_appointments_patient;

ALTER TABLE clean.appointments
    ADD CONSTRAINT fk_appointments_patient
    FOREIGN KEY (patient_id)
    REFERENCES clean.patients (patient_id);


ALTER TABLE clean.appointments
    DROP CONSTRAINT IF EXISTS fk_appointments_department;

ALTER TABLE clean.appointments
    ADD CONSTRAINT fk_appointments_department
    FOREIGN KEY (department_id)
    REFERENCES clean.departments (department_id);


ALTER TABLE clean.appointments
    DROP CONSTRAINT IF EXISTS fk_appointments_referral;

ALTER TABLE clean.appointments
    ADD CONSTRAINT fk_appointments_referral
    FOREIGN KEY (referral_id)
    REFERENCES clean.referrals (referral_id);

/*
ED visits may reference patients and facilities.
*/

ALTER TABLE clean.ed_visits
    DROP CONSTRAINT IF EXISTS fk_ed_visits_patient;

ALTER TABLE clean.ed_visits
    ADD CONSTRAINT fk_ed_visits_patient
    FOREIGN KEY (patient_id)
    REFERENCES clean.patients (patient_id);


ALTER TABLE clean.ed_visits
    DROP CONSTRAINT IF EXISTS fk_ed_visits_facility;

ALTER TABLE clean.ed_visits
    ADD CONSTRAINT fk_ed_visits_facility
    FOREIGN KEY (facility_id)
    REFERENCES clean.facilities (facility_id);

COMMIT;


--Verify that the constraints were added
SELECT
    table_name,
    constraint_name,
    constraint_type

FROM information_schema.table_constraints

WHERE table_schema = 'clean'
  AND constraint_type = 'FOREIGN KEY'

ORDER BY
    table_name,
    constraint_name;