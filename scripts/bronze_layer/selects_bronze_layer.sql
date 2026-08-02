/*=============================================================================
SECTION 4: PREVIEW THE RAW DATA
===============================================================================

Business question:
    What does the raw source data actually look like?

Why this matters:
    Looking at sample records helps us understand:
    - The format of customer keys
    - The format of product keys
    - Whether dates are stored as dates or numbers
    - Whether text contains spaces or abbreviations
    - Whether NULLs are visible
    - Whether the source data appears properly aligned with the columns

TOP (20):
    Returns only the first 20 records so that the results remain manageable.

Important:
    These queries only display records. They do not change them.
=============================================================================*/

SELECT TOP (20) *
FROM bronze.crm_cust_info;

SELECT TOP (20) *
FROM bronze.crm_prd_info;

SELECT TOP (20) *
FROM bronze.crm_sales_details;

SELECT TOP (20) *
FROM bronze.erp_cust_az12;

SELECT TOP (20) *
FROM bronze.erp_loc_a101;

SELECT TOP (20) *
FROM bronze.erp_px_cat_g1v2;
