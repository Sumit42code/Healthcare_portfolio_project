/*
Purpose:
Create approved mappings that convert inconsistent
raw categorical values into standard reporting values.


Blank and sentinel values are not mapped to valid categories.
They will remain NULL and get quality flags where appropriate.
*/

/*
Create the reference-mapping table
store the approved cleaning rules for 
inconsistent categorical values in one place.
*/

SELECT * from raw.appointments_raw;
SELECT * from raw.departments_raw;
SELECT * from raw.ed_visits_raw;
SELECT * from raw.facilities_raw;
SELECT * from raw.patients_raw;

SELECT DISTINCT
--Adding the text length can make whitespace problems clearer which is sometime hard to identify.
    '[' || COALESCE(hospital_region, 'NULL') || ']'
        AS hospital_region_value
FROM raw.facilities_raw
ORDER BY hospital_region_value;


SELECT DISTINCT
    '[' || COALESCE(gender, 'NULL') || ']'
        AS gender_value
FROM raw.patients_raw
ORDER BY gender_value;

SELECT DISTINCT
    '[' || COALESCE(referral_status, 'NULL') || ']'
        AS referral_status_value
FROM raw.referrals_raw
ORDER BY referral_status_value;

SELECT DISTINCT
    '[' || COALESCE(appointment_status, 'NULL') || ']'
        AS appointment_status_value
FROM raw.appointments_raw
ORDER BY appointment_status_value;

SELECT DISTINCT
    '[' || COALESCE(hospital_region, 'NULL') || ']'
        AS hosptial_region_value
FROM raw.facilities_raw
ORDER BY hosptial_region_value;

/*Create mapping*/

CREATE TABLE IF NOT EXISTS clean.reference_mappings (

    --Identifies which column or category the rule belongs to.
    mapping_group VARCHAR(50) NOT NULL,

    --Stores the raw lookup value after applying
    raw_value_normalised VARCHAR(100) NOT NULL,

    --Stores the approved value that will appear in the clean table and Power BI.
    standard_value VARCHAR(100) NOT NULL,

    PRIMARY KEY (
        mapping_group,
        raw_value_normalised
    )

);

/* not required
SELECT DISTINCT
    '[' || COALESCE(specialty_group, 'NULL') || ']'
        AS department_value
FROM raw.departments_raw
ORDER BY department_value; */

/*Inserting standerised value into the mapping table*/

INSERT INTO clean.reference_mappings (
    mapping_group,
    raw_value_normalised,
    standard_value
)
VALUES

    /* Hospital regions */

    ('hospital_region', 'northern', 'Northern'),
    ('hospital_region', 'midland', 'Midland'),
    ('hospital_region', 'central', 'Central'),
    ('hospital_region', 'southern', 'Southern'),

    /* Gender */

    ('gender', 'female', 'Female'),
    ('gender', 'male', 'Male'),
    ('gender', 'm', 'Male'),
    ('gender', 'gender diverse', 'Gender Diverse'),
    ('gender', 'gender-diverse', 'Gender Diverse'),
    ('gender', 'unknown', 'Unknown'),

    /* Referral status */

    ('referral_status', 'completed', 'Completed'),
    ('referral_status', 'cancelled', 'Cancelled'),
    ('referral_status', 'declined', 'Declined'),
    ('referral_status', 'decline', 'Declined'),
    ('referral_status', 'booked', 'Booked'),
    ('referral_status', 'waiting', 'Waiting'),
    ('referral_status', 'open', 'Open'),

    /* Appointment status */

    ('appointment_status', 'completed', 'Completed'),
    ('appointment_status', 'no show', 'No Show'),
    ('appointment_status', 'no-show', 'No Show'),
    ('appointment_status', 'cancelled', 'Cancelled'),
    ('appointment_status', 'rescheduled', 'Rescheduled'),
    ('appointment_status', 're-scheduled', 'Rescheduled'),
    ('appointment_status', 'scheduled', 'Scheduled')

--ON CONFLICT means the script can be run again 
--without creating duplicate mapping records.
ON CONFLICT (
    mapping_group,
    raw_value_normalised
)

/*
If the new row conflicts with an existing row, update the existing row’s 
standard_value using the newly supplied value.
*/
DO UPDATE SET
    standard_value = EXCLUDED.standard_value;

--Review the mappings
SELECT
    mapping_group,
    raw_value_normalised,
    standard_value

FROM clean.reference_mappings

ORDER BY
    mapping_group,
    raw_value_normalised;