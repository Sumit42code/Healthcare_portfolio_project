
/*
Purpose:
Load the original CSV files into the raw schema. Here i have two ways to import raw data.
for this project i used pgadmin to import data 

below is the 2nd method which also work well
-- Prevent accidental duplicate imports

TRUNCATE TABLE
    raw.appointments_raw,
    raw.referrals_raw,
    raw.ed_visits_raw,
    raw.patients_raw,
    raw.departments_raw,
    raw.facilities_raw;


-- Import dimension tables

\copy raw.facilities_raw
FROM 'data/raw/facilities_raw.csv'
WITH (
    FORMAT CSV,
    HEADER TRUE,
    ENCODING 'UTF8'
);


\copy raw.departments_raw
FROM 'data/raw/departments_raw.csv'
WITH (
    FORMAT CSV,
    HEADER TRUE,
    ENCODING 'UTF8'
);


\copy raw.patients_raw
FROM 'data/raw/patients_raw.csv'
WITH (
    FORMAT CSV,
    HEADER TRUE,
    ENCODING 'UTF8'
);


-- Import fact tables

\copy raw.referrals_raw
FROM 'data/raw/referrals_raw.csv'
WITH (
    FORMAT CSV,
    HEADER TRUE,
    ENCODING 'UTF8'
);


\copy raw.appointments_raw
FROM 'data/raw/appointments_raw.csv'
WITH (
    FORMAT CSV,
    HEADER TRUE,
    ENCODING 'UTF8'
);


\copy raw.ed_visits_raw
FROM 'data/raw/ed_visits_raw.csv'
WITH (
    FORMAT CSV,
    HEADER TRUE,
    ENCODING 'UTF8'
);
*/


/*
Validate the imported row counts
*/
SELECT
    'facilities_raw' AS table_name,
    COUNT(*) AS row_count
FROM raw.facilities_raw

UNION ALL

SELECT
    'departments_raw',
    COUNT(*)
FROM raw.departments_raw

UNION ALL

SELECT
    'patients_raw',
    COUNT(*)
FROM raw.patients_raw

UNION ALL

SELECT
    'referrals_raw',
    COUNT(*)
FROM raw.referrals_raw

UNION ALL

SELECT
    'appointments_raw',
    COUNT(*)
FROM raw.appointments_raw

UNION ALL

SELECT
    'ed_visits_raw',
    COUNT(*)
FROM raw.ed_visits_raw;

--Inspect the data 
SELECT * FROM raw.facilities_raw LIMIT 10;
SELECT * FROM raw.departments_raw LIMIT 10;
SELECT * FROM raw.patients_raw LIMIT 10;
SELECT * FROM raw.referrals_raw LIMIT 10;
SELECT * FROM raw.appointments_raw LIMIT 10;
SELECT * FROM raw.ed_visits_raw LIMIT 10;

