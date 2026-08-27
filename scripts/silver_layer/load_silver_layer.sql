/*=============================================================================
SELECT THE DATABASE
===============================================================================*/

USE DataWarehouse;
GO


/*=============================================================================
CREATE THE SILVER SCHEMA IF IT DOES NOT ALREADY EXIST
===============================================================================*/

IF SCHEMA_ID('silver') IS NULL
BEGIN
    EXEC ('CREATE SCHEMA silver');
END;
GO


/*=============================================================================
STORED PROCEDURE: LOAD SILVER LAYER
===============================================================================

Purpose:
    Load transformed and standardised records from the Bronze layer into the
    Silver layer.

Main business rules:
    1. Keep all raw records in Bronze.
    2. Keep one preferred customer record per customer ID in Silver.
    3. Prefer the newest customer record.
    4. If two records have the same date, prefer the most complete record.
    5. Standardise customer gender and marital status.
    6. Standardise product lines.
    7. Safely convert integer sales dates into SQL DATE values.
    8. Recalculate invalid sales and prices where possible.
    9. Standardise ERP gender and country values.
   10. Roll back the complete load if any table fails.
=============================================================================*/

CREATE OR ALTER PROCEDURE silver.load_silver
AS
BEGIN
    SET NOCOUNT ON;

    /*
        XACT_ABORT makes SQL Server terminate and roll back the transaction
        when a runtime error occurs.
    */
    SET XACT_ABORT ON;

    DECLARE
        @start_time       DATETIME2(3),
        @end_time         DATETIME2(3),
        @batch_start_time DATETIME2(3),
        @batch_end_time   DATETIME2(3),
        @rows_loaded      BIGINT;

    BEGIN TRY
        SET @batch_start_time = SYSDATETIME();

        PRINT '================================================';
        PRINT 'Loading Silver Layer';
        PRINT '================================================';

        /*
            Begin one transaction for the entire Silver load.

            If one table fails, the CATCH block rolls everything back.
            This prevents some Silver tables from being refreshed while
            others remain empty or outdated.
        */
        BEGIN TRANSACTION;


        /*=====================================================================
        1. LOAD SILVER CRM CUSTOMER TABLE
        =====================================================================*/

        SET @start_time = SYSDATETIME();

        PRINT '------------------------------------------------';
        PRINT 'Loading CRM Tables';
        PRINT '------------------------------------------------';

        PRINT '>> Truncating Table: silver.crm_cust_info';

        TRUNCATE TABLE silver.crm_cust_info;

        PRINT '>> Inserting Data Into: silver.crm_cust_info';


        /*
            customer_prepared performs two activities:

            1. Trims unnecessary spaces from text values.
            2. Calculates how complete each customer record is.

            The completeness score awards one point for every important field
            that contains a value.
        */
        ;WITH customer_prepared AS
        (
            SELECT
                cst_id,

                NULLIF(
                    LTRIM(RTRIM(cst_key)),
                    ''
                ) AS cst_key_clean,

                NULLIF(
                    LTRIM(RTRIM(cst_firstname)),
                    ''
                ) AS cst_firstname_clean,

                NULLIF(
                    LTRIM(RTRIM(cst_lastname)),
                    ''
                ) AS cst_lastname_clean,

                NULLIF(
                    LTRIM(RTRIM(cst_marital_status)),
                    ''
                ) AS cst_marital_status_raw,

                NULLIF(
                    LTRIM(RTRIM(cst_gndr)),
                    ''
                ) AS cst_gndr_raw,

                cst_create_date,

                /*
                    Calculate a completeness score.

                    Maximum score = 5 because five customer attributes
                    are evaluated.
                */
                (
                    CASE
                        WHEN cst_key IS NOT NULL
                         AND LTRIM(RTRIM(cst_key)) <> ''
                            THEN 1
                        ELSE 0
                    END
                    +
                    CASE
                        WHEN cst_firstname IS NOT NULL
                         AND LTRIM(RTRIM(cst_firstname)) <> ''
                            THEN 1
                        ELSE 0
                    END
                    +
                    CASE
                        WHEN cst_lastname IS NOT NULL
                         AND LTRIM(RTRIM(cst_lastname)) <> ''
                            THEN 1
                        ELSE 0
                    END
                    +
                    CASE
                        WHEN cst_marital_status IS NOT NULL
                         AND LTRIM(RTRIM(cst_marital_status)) <> ''
                            THEN 1
                        ELSE 0
                    END
                    +
                    CASE
                        WHEN cst_gndr IS NOT NULL
                         AND LTRIM(RTRIM(cst_gndr)) <> ''
                            THEN 1
                        ELSE 0
                    END
                ) AS completeness_score

            FROM bronze.crm_cust_info

            /*
                Customer records without an ID cannot be reliably identified
                or deduplicated.
            */
            WHERE cst_id IS NOT NULL
        ),
        customer_ranked AS
        (
            SELECT
                *,

                /*
                    Number all records belonging to the same customer.

                    Ranking rules:

                    1. Newest creation date comes first.
                    2. If dates are equal, the most complete record comes first.
                    3. The remaining columns make the result deterministic when
                       two records have the same date and completeness score.

                    The preferred record receives row_number = 1.
                */
                ROW_NUMBER() OVER
                (
                    PARTITION BY cst_id

                    ORDER BY
                        cst_create_date DESC,
                        completeness_score DESC,
                        cst_key_clean DESC,
                        cst_firstname_clean DESC,
                        cst_lastname_clean DESC,
                        cst_marital_status_raw DESC,
                        cst_gndr_raw DESC
                ) AS row_number

            FROM customer_prepared
        )
        INSERT INTO silver.crm_cust_info
        (
            cst_id,
            cst_key,
            cst_firstname,
            cst_lastname,
            cst_marital_status,
            cst_gndr,
            cst_create_date
        )
        SELECT
            cst_id,
            cst_key_clean,
            cst_firstname_clean,
            cst_lastname_clean,

            /*
                Convert marital-status abbreviations into readable values.

                Both abbreviated and already-expanded values are accepted.
            */
            CASE
                WHEN UPPER(cst_marital_status_raw)
                     IN ('S', 'SINGLE')
                    THEN 'Single'

                WHEN UPPER(cst_marital_status_raw)
                     IN ('M', 'MARRIED')
                    THEN 'Married'

                ELSE 'n/a'
            END AS cst_marital_status,

            /*
                Convert gender abbreviations into readable values.
            */
            CASE
                WHEN UPPER(cst_gndr_raw)
                     IN ('F', 'FEMALE')
                    THEN 'Female'

                WHEN UPPER(cst_gndr_raw)
                     IN ('M', 'MALE')
                    THEN 'Male'

                ELSE 'n/a'
            END AS cst_gndr,

            cst_create_date

        FROM customer_ranked

        /*
            Only insert the preferred record for each customer.
        */
        WHERE row_number = 1;


        /*
            @@ROWCOUNT contains the number of rows inserted by the statement
            immediately before it.
        */
        SET @rows_loaded = @@ROWCOUNT;
        SET @end_time = SYSDATETIME();

        PRINT '>> Rows Loaded: '
            + CAST(@rows_loaded AS NVARCHAR(30));

        PRINT '>> Load Duration: '
            + CAST(
                DATEDIFF(
                    SECOND,
                    @start_time,
                    @end_time
                ) AS NVARCHAR(30)
            )
            + ' seconds';

        PRINT '>> -------------';


        /*=====================================================================
        2. LOAD SILVER CRM PRODUCT TABLE
        =====================================================================*/

        SET @start_time = SYSDATETIME();

        PRINT '>> Truncating Table: silver.crm_prd_info';

        TRUNCATE TABLE silver.crm_prd_info;

        PRINT '>> Inserting Data Into: silver.crm_prd_info';


        /*
            product_prepared separates the category portion of the source
            product key from the actual product key.

            Example source key:
                AC_HE-HL-U509-R

            Category ID:
                AC_HE

            Product key:
                HL-U509-R
        */
        ;WITH product_prepared AS
        (
            SELECT
                prd_id,

                NULLIF(
                    LTRIM(RTRIM(prd_key)),
                    ''
                ) AS original_prd_key,

                /*
                    Extract the first five characters and replace the hyphen
                    with an underscore.

                    Example:
                        AC-HE becomes AC_HE
                */
                CASE
                    WHEN prd_key IS NULL
                        THEN NULL

                    ELSE REPLACE(
                        SUBSTRING(
                            LTRIM(RTRIM(prd_key)),
                            1,
                            5
                        ),
                        '-',
                        '_'
                    )
                END AS cat_id,

                /*
                    Extract the product portion beginning at character 7.

                    If the value is shorter than seven characters, preserve the
                    complete trimmed value rather than returning an invalid
                    substring.
                */
                CASE
                    WHEN prd_key IS NULL
                        THEN NULL

                    WHEN LEN(LTRIM(RTRIM(prd_key))) >= 7
                        THEN SUBSTRING(
                            LTRIM(RTRIM(prd_key)),
                            7,
                            LEN(LTRIM(RTRIM(prd_key)))
                        )

                    ELSE LTRIM(RTRIM(prd_key))
                END AS product_key,

                NULLIF(
                    LTRIM(RTRIM(prd_nm)),
                    ''
                ) AS product_name,

                /*
                    A missing product cost is represented as zero based on the
                    current Silver-layer business rule.
                */
                ISNULL(prd_cost, 0) AS product_cost,

                NULLIF(
                    LTRIM(RTRIM(prd_line)),
                    ''
                ) AS product_line_raw,

                /*
                    TRY_CONVERT returns NULL rather than stopping the procedure
                    when the value is not a valid date.
                */
                TRY_CONVERT(
                    DATE,
                    prd_start_dt
                ) AS product_start_date

            FROM bronze.crm_prd_info
        ),
        product_versions AS
        (
            SELECT
                *,

                /*
                    Find the start date of the next version of the same product.

                    LEAD looks at the following product-version row.
                */
                LEAD(product_start_date) OVER
                (
                    PARTITION BY original_prd_key

                    ORDER BY
                        product_start_date,
                        prd_id
                ) AS next_product_start_date

            FROM product_prepared
        )
        INSERT INTO silver.crm_prd_info
        (
            prd_id,
            cat_id,
            prd_key,
            prd_nm,
            prd_cost,
            prd_line,
            prd_start_dt,
            prd_end_dt
        )
        SELECT
            prd_id,
            cat_id,
            product_key,
            product_name,
            product_cost,

            /*
                Convert product-line codes into readable names.
            */
            CASE
                WHEN UPPER(product_line_raw)
                     IN ('M', 'MOUNTAIN')
                    THEN 'Mountain'

                WHEN UPPER(product_line_raw)
                     IN ('R', 'ROAD')
                    THEN 'Road'

                WHEN UPPER(product_line_raw)
                     IN ('S', 'OTHER SALES')
                    THEN 'Other Sales'

                WHEN UPPER(product_line_raw)
                     IN ('T', 'TOURING')
                    THEN 'Touring'

                ELSE 'n/a'
            END AS prd_line,

            product_start_date,

            /*
                The current product version ends one day before the next
                version begins.

                DATEADD is used instead of:
                    next_date - 1

                DATEADD works safely and clearly with SQL DATE values.

                The newest version has no next start date, so its end date
                remains NULL.
            */
            CASE
                WHEN next_product_start_date IS NULL
                    THEN NULL

                ELSE DATEADD(
                    DAY,
                    -1,
                    next_product_start_date
                )
            END AS product_end_date

        FROM product_versions;


        SET @rows_loaded = @@ROWCOUNT;
        SET @end_time = SYSDATETIME();

        PRINT '>> Rows Loaded: '
            + CAST(@rows_loaded AS NVARCHAR(30));

        PRINT '>> Load Duration: '
            + CAST(
                DATEDIFF(
                    SECOND,
                    @start_time,
                    @end_time
                ) AS NVARCHAR(30)
            )
            + ' seconds';

        PRINT '>> -------------';


        /*=====================================================================
        3. LOAD SILVER CRM SALES TABLE
        =====================================================================*/

        SET @start_time = SYSDATETIME();

        PRINT '>> Truncating Table: silver.crm_sales_details';

        TRUNCATE TABLE silver.crm_sales_details;

        PRINT '>> Inserting Data Into: silver.crm_sales_details';


        /*
            sales_prepared safely converts the source fields into temporary
            analytical values.

            The original Bronze values remain unchanged.
        */
        ;WITH sales_prepared AS
        (
            SELECT
                sls_ord_num,
                sls_prd_key,
                sls_cust_id,

                /*
                    Source sales dates are stored as integers in YYYYMMDD form.

                    Examples:
                        20131231 = 31 December 2013
                        0        = missing date

                    A date is accepted only when:
                        - It is not NULL
                        - It is not zero
                        - It contains exactly eight characters
                        - It can be converted into a real date

                    TRY_CONVERT returns NULL for values such as:
                        20231301
                        20230230
                        99999999
                */
                CASE
                    WHEN sls_order_dt IS NULL
                      OR sls_order_dt = 0
                      OR LEN(
                            CONVERT(
                                VARCHAR(20),
                                sls_order_dt
                            )
                         ) <> 8
                        THEN NULL

                    ELSE TRY_CONVERT(
                        DATE,
                        CONVERT(
                            CHAR(8),
                            sls_order_dt
                        ),
                        112
                    )
                END AS order_date,

                CASE
                    WHEN sls_ship_dt IS NULL
                      OR sls_ship_dt = 0
                      OR LEN(
                            CONVERT(
                                VARCHAR(20),
                                sls_ship_dt
                            )
                         ) <> 8
                        THEN NULL

                    ELSE TRY_CONVERT(
                        DATE,
                        CONVERT(
                            CHAR(8),
                            sls_ship_dt
                        ),
                        112
                    )
                END AS ship_date,

                CASE
                    WHEN sls_due_dt IS NULL
                      OR sls_due_dt = 0
                      OR LEN(
                            CONVERT(
                                VARCHAR(20),
                                sls_due_dt
                            )
                         ) <> 8
                        THEN NULL

                    ELSE TRY_CONVERT(
                        DATE,
                        CONVERT(
                            CHAR(8),
                            sls_due_dt
                        ),
                        112
                    )
                END AS due_date,

                /*
                    Convert numeric fields to decimals temporarily.

                    This prevents accidental integer division and reduces the
                    risk of overflow when quantity is multiplied by price.
                */
                TRY_CONVERT(
                    DECIMAL(18,2),
                    sls_sales
                ) AS raw_sales,

                TRY_CONVERT(
                    DECIMAL(18,2),
                    sls_quantity
                ) AS raw_quantity,

                TRY_CONVERT(
                    DECIMAL(18,2),
                    sls_price
                ) AS raw_price

            FROM bronze.crm_sales_details
        ),
        sales_with_price AS
        (
            SELECT
                *,

                /*
                    Determine a usable price.

                    Rule 1:
                        If the original price is positive, keep it.

                    Rule 2:
                        If the price is missing or invalid but sales and
                        quantity are valid, calculate:

                            price = sales / quantity

                    Rule 3:
                        If the price cannot be calculated, leave it NULL.
                */
                CASE
                    WHEN raw_price IS NOT NULL
                     AND raw_price > 0
                        THEN ABS(raw_price)

                    WHEN raw_sales IS NOT NULL
                     AND raw_sales > 0
                     AND raw_quantity IS NOT NULL
                     AND raw_quantity > 0
                        THEN raw_sales /
                             NULLIF(raw_quantity, 0)

                    ELSE NULL
                END AS corrected_price

            FROM sales_prepared
        ),
        sales_final AS
        (
            SELECT
                *,

                /*
                    Determine a usable sales amount.

                    Rule 1:
                        If sales is missing or non-positive, calculate:

                            quantity × corrected price

                    Rule 2:
                        If sales does not equal quantity × price, recalculate
                        it using quantity × price.

                    Rule 3:
                        If the existing sales amount is valid and consistent,
                        preserve it.

                    The difference tolerance of 0.01 allows for minor decimal
                    rounding differences.
                */
                CASE
                    WHEN raw_sales IS NULL
                      OR raw_sales <= 0
                    THEN
                        CASE
                            WHEN raw_quantity > 0
                             AND corrected_price > 0
                                THEN raw_quantity *
                                     corrected_price

                            ELSE NULL
                        END

                    WHEN raw_quantity > 0
                     AND corrected_price > 0
                     AND ABS(
                            raw_sales -
                            (
                                raw_quantity *
                                corrected_price
                            )
                         ) > 0.01
                        THEN raw_quantity *
                             corrected_price

                    ELSE raw_sales
                END AS corrected_sales

            FROM sales_with_price
        )
        INSERT INTO silver.crm_sales_details
        (
            sls_ord_num,
            sls_prd_key,
            sls_cust_id,
            sls_order_dt,
            sls_ship_dt,
            sls_due_dt,
            sls_sales,
            sls_quantity,
            sls_price
        )
        SELECT
            sls_ord_num,
            sls_prd_key,
            sls_cust_id,
            order_date,
            ship_date,
            due_date,
            corrected_sales,
            raw_quantity,
            corrected_price

        FROM sales_final;


        SET @rows_loaded = @@ROWCOUNT;
        SET @end_time = SYSDATETIME();

        PRINT '>> Rows Loaded: '
            + CAST(@rows_loaded AS NVARCHAR(30));

        PRINT '>> Load Duration: '
            + CAST(
                DATEDIFF(
                    SECOND,
                    @start_time,
                    @end_time
                ) AS NVARCHAR(30)
            )
            + ' seconds';

        PRINT '>> -------------';


        /*=====================================================================
        4. LOAD ERP CUSTOMER TABLE
        =====================================================================*/

        SET @start_time = SYSDATETIME();

        PRINT '------------------------------------------------';
        PRINT 'Loading ERP Tables';
        PRINT '------------------------------------------------';

        PRINT '>> Truncating Table: silver.erp_cust_az12';

        TRUNCATE TABLE silver.erp_cust_az12;

        PRINT '>> Inserting Data Into: silver.erp_cust_az12';


        ;WITH erp_customer_prepared AS
        (
            SELECT
                NULLIF(
                    LTRIM(RTRIM(cid)),
                    ''
                ) AS cid_raw,

                TRY_CONVERT(
                    DATE,
                    bdate
                ) AS birth_date,

                NULLIF(
                    LTRIM(RTRIM(gen)),
                    ''
                ) AS gender_raw

            FROM bronze.erp_cust_az12
        )
        INSERT INTO silver.erp_cust_az12
        (
            cid,
            bdate,
            gen
        )
        SELECT
            /*
                Remove the NAS prefix when it appears at the beginning
                of the customer identifier.

                Example:
                    NASAW00011000 becomes AW00011000
            */
            CASE
                WHEN UPPER(cid_raw) LIKE 'NAS%'
                    THEN SUBSTRING(
                        cid_raw,
                        4,
                        LEN(cid_raw)
                    )

                ELSE cid_raw
            END AS cid,

            /*
                Future birth dates are not logically possible, so they become
                NULL in the Silver layer.
            */
            CASE
                WHEN birth_date > CAST(GETDATE() AS DATE)
                    THEN NULL

                ELSE birth_date
            END AS bdate,

            /*
                Standardise ERP gender values.
            */
            CASE
                WHEN UPPER(gender_raw)
                     IN ('F', 'FEMALE')
                    THEN 'Female'

                WHEN UPPER(gender_raw)
                     IN ('M', 'MALE')
                    THEN 'Male'

                ELSE 'n/a'
            END AS gen

        FROM erp_customer_prepared;


        SET @rows_loaded = @@ROWCOUNT;
        SET @end_time = SYSDATETIME();

        PRINT '>> Rows Loaded: '
            + CAST(@rows_loaded AS NVARCHAR(30));

        PRINT '>> Load Duration: '
            + CAST(
                DATEDIFF(
                    SECOND,
                    @start_time,
                    @end_time
                ) AS NVARCHAR(30)
            )
            + ' seconds';

        PRINT '>> -------------';


        /*=====================================================================
        5. LOAD ERP LOCATION TABLE
        =====================================================================*/

        SET @start_time = SYSDATETIME();

        PRINT '>> Truncating Table: silver.erp_loc_a101';

        TRUNCATE TABLE silver.erp_loc_a101;

        PRINT '>> Inserting Data Into: silver.erp_loc_a101';


        ;WITH erp_location_prepared AS
        (
            SELECT
                NULLIF(
                    LTRIM(RTRIM(cid)),
                    ''
                ) AS cid_raw,

                NULLIF(
                    LTRIM(RTRIM(cntry)),
                    ''
                ) AS country_raw

            FROM bronze.erp_loc_a101
        )
        INSERT INTO silver.erp_loc_a101
        (
            cid,
            cntry
        )
        SELECT
            /*
                Remove hyphens so that the ERP location customer key can match
                the CRM customer key.

                Example:
                    AW-00011000 becomes AW00011000
            */
            REPLACE(
                cid_raw,
                '-',
                ''
            ) AS cid,

            /*
                Standardise common country abbreviations.
            */
            CASE
                WHEN UPPER(country_raw) = 'DE'
                    THEN 'Germany'

                WHEN UPPER(country_raw)
                     IN ('US', 'USA')
                    THEN 'United States'

                WHEN country_raw IS NULL
                    THEN 'n/a'

                ELSE country_raw
            END AS cntry

        FROM erp_location_prepared;


        SET @rows_loaded = @@ROWCOUNT;
        SET @end_time = SYSDATETIME();

        PRINT '>> Rows Loaded: '
            + CAST(@rows_loaded AS NVARCHAR(30));

        PRINT '>> Load Duration: '
            + CAST(
                DATEDIFF(
                    SECOND,
                    @start_time,
                    @end_time
                ) AS NVARCHAR(30)
            )
            + ' seconds';

        PRINT '>> -------------';


        /*=====================================================================
        6. LOAD ERP PRODUCT CATEGORY TABLE
        =====================================================================*/

        SET @start_time = SYSDATETIME();

        PRINT '>> Truncating Table: silver.erp_px_cat_g1v2';

        TRUNCATE TABLE silver.erp_px_cat_g1v2;

        PRINT '>> Inserting Data Into: silver.erp_px_cat_g1v2';


        INSERT INTO silver.erp_px_cat_g1v2
        (
            id,
            cat,
            subcat,
            maintenance
        )
        SELECT
            NULLIF(
                LTRIM(RTRIM(id)),
                ''
            ) AS id,

            COALESCE(
                NULLIF(
                    LTRIM(RTRIM(cat)),
                    ''
                ),
                'n/a'
            ) AS cat,

            COALESCE(
                NULLIF(
                    LTRIM(RTRIM(subcat)),
                    ''
                ),
                'n/a'
            ) AS subcat,

            COALESCE(
                NULLIF(
                    LTRIM(RTRIM(maintenance)),
                    ''
                ),
                'n/a'
            ) AS maintenance

        FROM bronze.erp_px_cat_g1v2;


        SET @rows_loaded = @@ROWCOUNT;
        SET @end_time = SYSDATETIME();

        PRINT '>> Rows Loaded: '
            + CAST(@rows_loaded AS NVARCHAR(30));

        PRINT '>> Load Duration: '
            + CAST(
                DATEDIFF(
                    SECOND,
                    @start_time,
                    @end_time
                ) AS NVARCHAR(30)
            )
            + ' seconds';

        PRINT '>> -------------';


        /*=====================================================================
        COMMIT THE COMPLETE SILVER LOAD
        =====================================================================*/

        /*
            All six tables loaded successfully, so make the changes permanent.
        */
        COMMIT TRANSACTION;

        SET @batch_end_time = SYSDATETIME();

        PRINT '================================================';
        PRINT 'Loading Silver Layer Completed Successfully';

        PRINT 'Total Load Duration: '
            + CAST(
                DATEDIFF(
                    SECOND,
                    @batch_start_time,
                    @batch_end_time
                ) AS NVARCHAR(30)
            )
            + ' seconds';

        PRINT '================================================';

    END TRY

    BEGIN CATCH

        /*
            Roll back every Silver-layer change if any statement failed.

            This restores the Silver tables to their state before the
            procedure started.
        */
        IF XACT_STATE() <> 0
        BEGIN
            ROLLBACK TRANSACTION;
        END;

        PRINT '================================================';
        PRINT 'ERROR OCCURRED DURING LOADING SILVER LAYER';

        PRINT 'Error Number: '
            + CAST(
                ERROR_NUMBER()
                AS NVARCHAR(30)
            );

        PRINT 'Error Message: '
            + ERROR_MESSAGE();

        PRINT 'Error Line: '
            + CAST(
                ERROR_LINE()
                AS NVARCHAR(30)
            );

        PRINT 'Error Procedure: '
            + COALESCE(
                ERROR_PROCEDURE(),
                'Not available'
            );

        PRINT 'Error State: '
            + CAST(
                ERROR_STATE()
                AS NVARCHAR(30)
            );

        PRINT '================================================';

        /*
            THROW ensures SSMS displays the actual error.
        */
        THROW;

    END CATCH;
END;
GO
/*=============================================================================
EXECUTE THE SILVER LOAD
=============================================================================*/

EXEC silver.load_silver;
GO
