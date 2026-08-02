--Explaratory data analysis.
-- Explore all objects in the database

SELECT * FROM INFORMATION_SCHEMA.TABLES

-- explore all columns in the database
-- check the schemas
SELECT * FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'dim_customers'
