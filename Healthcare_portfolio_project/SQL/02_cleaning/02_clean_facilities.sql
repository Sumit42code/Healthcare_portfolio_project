/*
Purpose:
Create a cleaned facility dimension from raw.facilities_raw.

Cleaning rules:
- Trim text values
- Standardise identifiers to uppercase
- Standardise descriptive text
- Apply the approved hospital-region mapping
- Convert valid bed capacity values to INTEGER
- Remove exact duplicate records
- Preserve raw.facilities_raw without modification
*/

/*
confirm extra duplicates 
*/
SELECT
    UPPER(BTRIM(facility_id)) AS facility_id,
    BTRIM(facility_name) AS facility_name,
    LOWER(BTRIM(hospital_region)) AS region_lookup,
    BTRIM(city) AS city,
    BTRIM(facility_type) AS facility_type,
    BTRIM(bed_capacity) AS bed_capacity,
    COUNT(*) AS occurrence_count

FROM raw.facilities_raw

GROUP BY
    UPPER(BTRIM(facility_id)),
    BTRIM(facility_name),
    LOWER(BTRIM(hospital_region)),
    BTRIM(city),
    BTRIM(facility_type),
    BTRIM(bed_capacity)

HAVING COUNT(*) > 1;

/*
create the clean table
*/
drop table if EXISTS clean.facilities;

CREATE TABLE clean.facilities(
    facility_id VARCHAR(10) PRIMARY KEY,
    facility_name VARCHAR(100) NOT NULL,
    hospital_region VARCHAR(20) NOT NULL,
    city VARCHAR(60) NOT NULL,
    facility_type VARCHAR(50) NOT NULL,
    bed_capacity INTEGER,

    constraint chk_facilities_region
    CHECK(
        hospital_region IN('Northern','Midland','Central','Southern')
    ),

    constraint chk_facilities_type
    CHECK(
        facility_type IN ('Tertiary Hospital','Regional Hospital','Community Hospital')
    ),

    CONSTRAINT chk_facilities_bed_capacity
    CHECK (
        bed_capacity IS NULL
        OR bed_capacity > 0
    )
);

/*
Standerdise the raw rocords
*/

WITH standardised_facilities AS (
    SELECT
        UPPER(NULLIF(BTRIM(facility_id), '')) AS facility_id,
        INITCAP(LOWER(NULLIF(BTRIM(facility_name), ''))) AS facility_name,
        LOWER(NULLIF(BTRIM(hospital_region), '')) AS region_lookup,
        INITCAP(LOWER(NULLIF(BTRIM(city), ''))) AS city,
        INITCAP(LOWER(NULLIF(BTRIM(facility_type), ''))) AS facility_type,
        CASE
            WHEN BTRIM(COALESCE(bed_capacity, '')) ~ '^[1-9][0-9]*$'
            THEN BTRIM(bed_capacity)::INTEGER
            ELSE NULL
        END AS bed_capacity
    FROM raw.facilities_raw
),
deduplicated_facilities AS (
    SELECT DISTINCT
        facility_id,
        facility_name,
        region_lookup,
        city,
        facility_type,
        bed_capacity
    FROM standardised_facilities
)
INSERT INTO clean.facilities (
    facility_id,
    facility_name,
    hospital_region,
    city,
    facility_type,
    bed_capacity
)
SELECT
    d.facility_id,
    d.facility_name,
    region_map.standard_value AS hospital_region,
    d.city,
    d.facility_type,
    d.bed_capacity
FROM deduplicated_facilities AS d
LEFT JOIN clean.reference_mappings AS region_map
    ON region_map.mapping_group = 'hospital_region'
   AND region_map.raw_value_normalised = d.region_lookup;
/*
Validate row counts
*/
SELECT
    (SELECT COUNT(*)
     FROM raw.facilities_raw) AS raw_rows,

    (SELECT COUNT(*)
     FROM clean.facilities) AS clean_rows,

    (SELECT COUNT(*)
     FROM raw.facilities_raw)

    -

    (SELECT COUNT(*)
     FROM clean.facilities) AS removed_rows;


--Validate uniqueness
SELECT
    COUNT(*) AS total_rows,

    COUNT(
        DISTINCT facility_id
    ) AS unique_facility_ids

FROM clean.facilities;

--Validate required values
SELECT *
FROM clean.facilities

WHERE facility_id IS NULL
   OR facility_name IS NULL
   OR hospital_region IS NULL
   OR city IS NULL
   OR facility_type IS NULL;

   /*
   Review the regional categories
   */
Select
    hospital_region,
    count(*) as facility_count
from clean.facilities 
group by hospital_region
order by hospital_region;

/*
Review the final table
*/
SELECT *
FROM clean.facilities
ORDER BY facility_id;