/*
===============================================================================
Stored Procedure: Load Bronze Layer (Source -> Bronze)
===============================================================================
Script Purpose:
    This stored procedure loads data into the 'bronze' schema from external CSV files. 
    It performs the following actions:
    - Truncates the bronze tables before loading data.
    - Uses the `BULK INSERT` command to load data from csv Files to bronze tables.

Parameters:
    None. 
	  This stored procedure does not accept any parameters or return any values.

Usage Example:
    EXEC bronze.load_bronze;
===============================================================================
*/
USE DataWarehouse;
GO

CREATE OR ALTER PROCEDURE bronze.load_bronze
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE
        @start_time DATETIME2,
        @end_time DATETIME2,
        @batch_start_time DATETIME2,
        @batch_end_time DATETIME2,
        @rows_loaded BIGINT;

    BEGIN TRY
        SET @batch_start_time = SYSDATETIME();

        PRINT '================================================';
        PRINT 'Loading Bronze Layer';
        PRINT '================================================';

        ------------------------------------------------
        -- CRM TABLES
        ------------------------------------------------
        PRINT '------------------------------------------------';
        PRINT 'Loading CRM Tables';
        PRINT '------------------------------------------------';

        ------------------------------------------------
        -- CRM Customer Information
        ------------------------------------------------
        SET @start_time = SYSDATETIME();

        PRINT '>> Truncating Table: bronze.crm_cust_info';
        TRUNCATE TABLE bronze.crm_cust_info;

        PRINT '>> Loading: cust_info.csv';

        BULK INSERT bronze.crm_cust_info
        FROM 'D:\sql-data-warehouse-project\sql-data-warehouse-project\datasets\source_crm\cust_info.csv'
        WITH
        (
            FORMAT = 'CSV',
            FIRSTROW = 2,
            FIELDQUOTE = '"',
            FIELDTERMINATOR = ',',
            ROWTERMINATOR = '0x0a',
            CODEPAGE = '65001',
            TABLOCK
        );

        SET @rows_loaded = @@ROWCOUNT;
        SET @end_time = SYSDATETIME();

        PRINT '>> Rows Loaded: ' + CAST(@rows_loaded AS NVARCHAR(20));
        PRINT '>> Load Duration: '
            + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS NVARCHAR(20))
            + ' seconds';
        PRINT '>> -------------';

        ------------------------------------------------
        -- CRM Product Information
        ------------------------------------------------
        SET @start_time = SYSDATETIME();

        PRINT '>> Truncating Table: bronze.crm_prd_info';
        TRUNCATE TABLE bronze.crm_prd_info;

        PRINT '>> Loading: prd_info.csv';

        BULK INSERT bronze.crm_prd_info
        FROM 'D:\sql-data-warehouse-project\sql-data-warehouse-project\datasets\source_crm\prd_info.csv'
        WITH
        (
            FORMAT = 'CSV',
            FIRSTROW = 2,
            FIELDQUOTE = '"',
            FIELDTERMINATOR = ',',
            ROWTERMINATOR = '0x0a',
            CODEPAGE = '65001',
            TABLOCK
        );

        SET @rows_loaded = @@ROWCOUNT;
        SET @end_time = SYSDATETIME();

        PRINT '>> Rows Loaded: ' + CAST(@rows_loaded AS NVARCHAR(20));
        PRINT '>> Load Duration: '
            + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS NVARCHAR(20))
            + ' seconds';
        PRINT '>> -------------';

        ------------------------------------------------
        -- CRM Sales Details
        ------------------------------------------------
        SET @start_time = SYSDATETIME();

        PRINT '>> Truncating Table: bronze.crm_sales_details';
        TRUNCATE TABLE bronze.crm_sales_details;

        PRINT '>> Loading: sales_details.csv';

        BULK INSERT bronze.crm_sales_details
        FROM 'D:\sql-data-warehouse-project\sql-data-warehouse-project\datasets\source_crm\sales_details.csv'
        WITH
        (
            FORMAT = 'CSV',
            FIRSTROW = 2,
            FIELDQUOTE = '"',
            FIELDTERMINATOR = ',',
            ROWTERMINATOR = '0x0a',
            CODEPAGE = '65001',
            TABLOCK
        );

        SET @rows_loaded = @@ROWCOUNT;
        SET @end_time = SYSDATETIME();

        PRINT '>> Rows Loaded: ' + CAST(@rows_loaded AS NVARCHAR(20));
        PRINT '>> Load Duration: '
            + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS NVARCHAR(20))
            + ' seconds';
        PRINT '>> -------------';

        ------------------------------------------------
        -- ERP TABLES
        ------------------------------------------------
        PRINT '------------------------------------------------';
        PRINT 'Loading ERP Tables';
        PRINT '------------------------------------------------';

        ------------------------------------------------
        -- ERP Location
        ------------------------------------------------
        SET @start_time = SYSDATETIME();

        PRINT '>> Truncating Table: bronze.erp_loc_a101';
        TRUNCATE TABLE bronze.erp_loc_a101;

        PRINT '>> Loading: LOC_A101.csv';

        BULK INSERT bronze.erp_loc_a101
        FROM 'D:\sql-data-warehouse-project\sql-data-warehouse-project\datasets\source_erp\LOC_A101.csv'
        WITH
        (
            FORMAT = 'CSV',
            FIRSTROW = 2,
            FIELDQUOTE = '"',
            FIELDTERMINATOR = ',',
            ROWTERMINATOR = '0x0a',
            CODEPAGE = '65001',
            TABLOCK
        );

        SET @rows_loaded = @@ROWCOUNT;
        SET @end_time = SYSDATETIME();

        PRINT '>> Rows Loaded: ' + CAST(@rows_loaded AS NVARCHAR(20));
        PRINT '>> Load Duration: '
            + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS NVARCHAR(20))
            + ' seconds';
        PRINT '>> -------------';

        ------------------------------------------------
        -- ERP Customer
        ------------------------------------------------
        SET @start_time = SYSDATETIME();

        PRINT '>> Truncating Table: bronze.erp_cust_az12';
        TRUNCATE TABLE bronze.erp_cust_az12;

        PRINT '>> Loading: CUST_AZ12.csv';

        BULK INSERT bronze.erp_cust_az12
        FROM 'D:\sql-data-warehouse-project\sql-data-warehouse-project\datasets\source_erp\CUST_AZ12.csv'
        WITH
        (
            FORMAT = 'CSV',
            FIRSTROW = 2,
            FIELDQUOTE = '"',
            FIELDTERMINATOR = ',',
            ROWTERMINATOR = '0x0a',
            CODEPAGE = '65001',
            TABLOCK
        );

        SET @rows_loaded = @@ROWCOUNT;
        SET @end_time = SYSDATETIME();

        PRINT '>> Rows Loaded: ' + CAST(@rows_loaded AS NVARCHAR(20));
        PRINT '>> Load Duration: '
            + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS NVARCHAR(20))
            + ' seconds';
        PRINT '>> -------------';

        ------------------------------------------------
        -- ERP Product Category
        ------------------------------------------------
        SET @start_time = SYSDATETIME();

        PRINT '>> Truncating Table: bronze.erp_px_cat_g1v2';
        TRUNCATE TABLE bronze.erp_px_cat_g1v2;

        PRINT '>> Loading: PX_CAT_G1V2.csv';

        BULK INSERT bronze.erp_px_cat_g1v2
        FROM 'D:\sql-data-warehouse-project\sql-data-warehouse-project\datasets\source_erp\PX_CAT_G1V2.csv'
        WITH
        (
            FORMAT = 'CSV',
            FIRSTROW = 2,
            FIELDQUOTE = '"',
            FIELDTERMINATOR = ',',
            ROWTERMINATOR = '0x0a',
            CODEPAGE = '65001',
            TABLOCK
        );

        SET @rows_loaded = @@ROWCOUNT;
        SET @end_time = SYSDATETIME();

        PRINT '>> Rows Loaded: ' + CAST(@rows_loaded AS NVARCHAR(20));
        PRINT '>> Load Duration: '
            + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS NVARCHAR(20))
            + ' seconds';
        PRINT '>> -------------';

        ------------------------------------------------
        -- Completion
        ------------------------------------------------
        SET @batch_end_time = SYSDATETIME();

        PRINT '==========================================';
        PRINT 'Loading Bronze Layer Completed';
        PRINT 'Total Load Duration: '
            + CAST(
                DATEDIFF(
                    SECOND,
                    @batch_start_time,
                    @batch_end_time
                ) AS NVARCHAR(20)
            )
            + ' seconds';
        PRINT '==========================================';
    END TRY
    BEGIN CATCH
        PRINT '==========================================';
        PRINT 'ERROR OCCURRED DURING BRONZE LAYER LOAD';
        PRINT 'Error Number: '
            + CAST(ERROR_NUMBER() AS NVARCHAR(20));
        PRINT 'Error Message: '
            + ERROR_MESSAGE();
        PRINT 'Error Line: '
            + CAST(ERROR_LINE() AS NVARCHAR(20));
        PRINT 'Error Procedure: '
            + COALESCE(ERROR_PROCEDURE(), 'N/A');
        PRINT '==========================================';

        THROW;
    END CATCH;
END;
GO

--Executing the load
EXEC bronze.load_bronze;
GO
