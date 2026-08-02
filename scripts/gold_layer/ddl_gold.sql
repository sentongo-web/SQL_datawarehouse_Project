/*=============================================================================
DDL SCRIPT: CREATE GOLD-LAYER VIEWS
===============================================================================

Purpose:
    Create business-ready dimensions and a sales fact view from the cleaned
    Silver-layer tables.

Gold model:
    gold.dim_customers
    gold.dim_products
    gold.fact_sales

Important design decision:
    Because these objects are views, stable source identifiers are used as the
    dimension keys.

    A production warehouse should normally use physical dimension tables with
    permanently stored surrogate keys.
=============================================================================*/

USE DataWarehouse;
GO


/*=============================================================================
CREATE THE GOLD SCHEMA IF IT DOES NOT EXIST
===============================================================================

Without this section, CREATE VIEW fails when the gold schema has not already
been created.
=============================================================================*/

IF SCHEMA_ID('gold') IS NULL
BEGIN
    EXEC ('CREATE SCHEMA gold');
END;
GO


/*=============================================================================
CREATE DIMENSION: gold.dim_customers
===============================================================================

Grain:
    One row represents one customer.

Sources:
    silver.crm_cust_info
        Main customer identity and CRM attributes.

    silver.erp_cust_az12
        Customer birth date and ERP gender.

    silver.erp_loc_a101
        Customer country.

Important rules:
    1. CRM is the preferred gender source.
    2. ERP gender is used when CRM gender is unavailable.
    3. One ERP row is returned per customer identifier.
    4. Customer ID is used as a stable view-based key.
    5. An Unknown customer record is provided with key -1.
=============================================================================*/

CREATE OR ALTER VIEW gold.dim_customers
AS

WITH erp_customer_one_row AS
(
    /*
        Reduce the ERP customer source to one row per customer ID.

        my Silver checks may currently show no duplicate IDs. This grouping
        is still useful as a protection against future source duplicates.

        MAX is harmless when only one row exists.
    */
    SELECT
        cid,

        MAX(bdate) AS bdate,

        /*
            Prefer a real gender value over 'n/a'.

            When every source value is 'n/a', the final COALESCE returns 'n/a'.
        */
        COALESCE(
            MAX(
                CASE
                    WHEN gen <> 'n/a' THEN gen
                END
            ),
            'n/a'
        ) AS gen

    FROM silver.erp_cust_az12
    GROUP BY cid
),
erp_location_one_row AS
(
    /*
        Reduce the ERP location source to one row per customer ID.
    */
    SELECT
        cid,

        COALESCE(
            MAX(
                CASE
                    WHEN cntry <> 'n/a' THEN cntry
                END
            ),
            'n/a'
        ) AS cntry

    FROM silver.erp_loc_a101
    GROUP BY cid
)

SELECT
    /*
        Use the customer ID as a stable dimension key while Gold remains
        view-based.

        Unlike ROW_NUMBER(), this value does not change when another customer
        is added.
    */
    CAST(ci.cst_id AS BIGINT) AS customer_key,

    ci.cst_id AS customer_id,
    ci.cst_key AS customer_number,
    ci.cst_firstname AS first_name,
    ci.cst_lastname AS last_name,

    /*
        CONCAT safely handles a NULL first or last name.
    */
    NULLIF(
        LTRIM(
            RTRIM(
                CONCAT(
                    ci.cst_firstname,
                    ' ',
                    ci.cst_lastname
                )
            )
        ),
        ''
    ) AS customer_name,

    /*
        Use 'n/a' when no country match exists.
    */
    COALESCE(
        NULLIF(la.cntry, 'n/a'),
        'n/a'
    ) AS country,

    COALESCE(
        NULLIF(ci.cst_marital_status, ''),
        'n/a'
    ) AS marital_status,

    /*
        Gender source priority:

        1. Use CRM gender when it is populated and not 'n/a'.
        2. Otherwise use ERP gender.
        3. If both are unavailable, use 'n/a'.
    */
    COALESCE(
        NULLIF(ci.cst_gndr, 'n/a'),
        NULLIF(ca.gen, 'n/a'),
        'n/a'
    ) AS gender,

    ca.bdate AS birthdate,
    ci.cst_create_date AS create_date

FROM silver.crm_cust_info AS ci

LEFT JOIN erp_customer_one_row AS ca
    ON ci.cst_key = ca.cid

LEFT JOIN erp_location_one_row AS la
    ON ci.cst_key = la.cid

/*
    Reserve -1 for the Unknown customer record.
*/
WHERE ci.cst_id <> -1


UNION ALL


/*
    Unknown customer member.

    Fact records that cannot find a matching customer will use customer_key -1.

    This avoids NULL foreign keys in the fact view.
*/
SELECT
    CAST(-1 AS BIGINT) AS customer_key,
    NULL AS customer_id,
    'UNKNOWN' AS customer_number,
    'Unknown' AS first_name,
    'Customer' AS last_name,
    'Unknown Customer' AS customer_name,
    'n/a' AS country,
    'n/a' AS marital_status,
    'n/a' AS gender,
    CAST(NULL AS DATE) AS birthdate,
    CAST(NULL AS DATE) AS create_date;
GO


/*=============================================================================
CREATE DIMENSION: gold.dim_products
===============================================================================

Grain:
    One row represents one current product.

Sources:
    silver.crm_prd_info
    silver.erp_px_cat_g1v2

Important rules:
    1. Only current product records are included.
    2. Current records are identified by prd_end_dt IS NULL.
    3. Only one current record is selected per product number.
    4. Product ID is used as the stable view-based dimension key.
    5. An Unknown product record is created with key -1.
=============================================================================*/

CREATE OR ALTER VIEW gold.dim_products
AS

WITH current_product_ranked AS
(
    SELECT
        pn.*,

        /*
            Protect against a situation where more than one product record has
            a NULL end date for the same product number.

            The most recent start date is preferred.
        */
        ROW_NUMBER() OVER
        (
            PARTITION BY pn.prd_key

            ORDER BY
                pn.prd_start_dt DESC,
                pn.prd_id DESC
        ) AS current_record_rank

    FROM silver.crm_prd_info AS pn

    /*
        Keep only current product versions.
    */
    WHERE pn.prd_end_dt IS NULL
),
category_one_row AS
(
    /*
        Reduce the category source to one row per category ID.

        If my duplicate checks return zero rows, MAX simply returns the only
        available value.
    */
    SELECT
        id,

        COALESCE(
            MAX(NULLIF(cat, 'n/a')),
            'n/a'
        ) AS cat,

        COALESCE(
            MAX(NULLIF(subcat, 'n/a')),
            'n/a'
        ) AS subcat,

        COALESCE(
            MAX(NULLIF(maintenance, 'n/a')),
            'n/a'
        ) AS maintenance

    FROM silver.erp_px_cat_g1v2
    GROUP BY id
)

SELECT
    /*
        Use product ID as a stable key for this view-based implementation.
    */
    CAST(pn.prd_id AS BIGINT) AS product_key,

    pn.prd_id AS product_id,
    pn.prd_key AS product_number,
    pn.prd_nm AS product_name,
    pn.cat_id AS category_id,

    COALESCE(pc.cat, 'n/a')
        AS category,

    COALESCE(pc.subcat, 'n/a')
        AS subcategory,

    COALESCE(pc.maintenance, 'n/a')
        AS maintenance,

    pn.prd_cost AS cost,
    pn.prd_line AS product_line,
    pn.prd_start_dt AS start_date,

    /*
        The current product record has no end date.
        Including the column makes the dimensional meaning explicit.
    */
    pn.prd_end_dt AS end_date

FROM current_product_ranked AS pn

LEFT JOIN category_one_row AS pc
    ON pn.cat_id = pc.id

/*
    Retain one current record for every product number.
*/
WHERE
    pn.current_record_rank = 1
    AND pn.prd_id <> -1


UNION ALL


/*
    Unknown product member.

    Sales that cannot find a product use product_key -1.
*/
SELECT
    CAST(-1 AS BIGINT) AS product_key,
    NULL AS product_id,
    'UNKNOWN' AS product_number,
    'Unknown Product' AS product_name,
    'UNKNOWN' AS category_id,
    'n/a' AS category,
    'n/a' AS subcategory,
    'n/a' AS maintenance,
    CAST(0 AS DECIMAL(18,2)) AS cost,
    'n/a' AS product_line,
    CAST(NULL AS DATE) AS start_date,
    CAST(NULL AS DATE) AS end_date;
GO


/*=============================================================================
CREATE FACT VIEW: gold.fact_sales
===============================================================================

Grain:
    One row represents one sales line from silver.crm_sales_details.

Important:
    order_number is not necessarily unique.

    One order can contain several products, so multiple fact rows may share
    the same order number.

Dimension-key rules:
    - Matching customer: use the customer dimension key.
    - Missing customer: use -1.
    - Matching product: use the product dimension key.
    - Missing product: use -1.

The LEFT JOIN preserves sales even when the related dimension record is
missing.
=============================================================================*/

CREATE OR ALTER VIEW gold.fact_sales
AS

SELECT
    sd.sls_ord_num AS order_number,

    /*
        Use -1 when the product is not found in the current product dimension.
    */
    COALESCE(
        pr.product_key,
        CAST(-1 AS BIGINT)
    ) AS product_key,

    /*
        Use -1 when the customer cannot be matched.
    */
    COALESCE(
        cu.customer_key,
        CAST(-1 AS BIGINT)
    ) AS customer_key,

    sd.sls_order_dt AS order_date,
    sd.sls_ship_dt AS shipping_date,
    sd.sls_due_dt AS due_date,
    sd.sls_sales AS sales_amount,
    sd.sls_quantity AS quantity,
    sd.sls_price AS price

FROM silver.crm_sales_details AS sd

LEFT JOIN gold.dim_products AS pr
    ON sd.sls_prd_key = pr.product_number
   AND pr.product_key <> -1

LEFT JOIN gold.dim_customers AS cu
    ON sd.sls_cust_id = cu.customer_id
   AND cu.customer_key <> -1;
GO
