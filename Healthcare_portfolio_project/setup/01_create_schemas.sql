/*
Purpose:
Create separate schemas for the raw data, cleaned data,
and analysis-ready database objects.
*/

CREATE SCHEMA IF NOT EXISTS raw;

CREATE SCHEMA IF NOT EXISTS clean;

CREATE SCHEMA IF NOT EXISTS analytics;

/*
raw: stores the CSV data exactly as received.
clean: stores standardised, typed and validated data.
analytics: stores views created for business analysis and Power BI.
*/
SELECT
    schema_name
FROM information_schema.schemata
WHERE schema_name IN (
    'raw',
    'clean',
    'analytics'
)
ORDER BY schema_name;