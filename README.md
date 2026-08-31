# SQL Data Warehouse Project

[Live Project Link](https://sentongo-web.github.io/SQL_datawarehouse_Project/)

A SQL Server data warehouse built from raw CRM and ERP exports. This project covers the full ETL pipeline using T-SQL: raw data ingestion, cleansing and standardization, dimensional modeling, automated quality checks, and reporting views.

## The Problem

Imagine a company running two siloed systems: a CRM handling customer profiles and sales transactions, and an ERP tracking products and store locations. Each system exports separate CSV files with inconsistent keys, localized status codes, and formatting discrepancies.

Before building downstream reporting or analytics dashboards, these sources must be reconciled. This project ingests the raw exports, cleans and standardizes the records, resolves cross-system mismatches, and outputs a clean star schema ready for querying.

## Architecture

The warehouse uses a Medallion (Bronze, Silver, Gold) architecture:

![Data Architecture](docs/model_images/data_architecture.png)

* **Bronze (Raw Load):** Ingests CSV files as-is into staging tables using `BULK INSERT` to maintain a full audit trail.
* **Silver (Cleansing & Transformation):** Handles data hygiene, safe date parsing, code expansion, and sales value reconciliations. The Silver layer load runs within an explicit transaction to ensure atomic processing and prevent partial loads.
* **Gold (Business Layer):** Exposes clean views structured as a star schema, including dimension tables, a fact table, and specialized reporting views for customer and product analytics.

## Data Model

The Gold layer uses a star schema structure centered around transactions:

* `gold.fact_sales` – Core transaction records containing order details, quantities, line items, and monetary totals.
* `gold.dim_customers` – Unified customer records joining demographic data from the CRM with location data from the ERP.
* `gold.dim_products` – Product catalog with hierarchy, pricing history, and supplier metadata.

Additionally, two aggregated reporting views support direct business intelligence tasks:

* `gold.report_customer_metrics` – Customer lifetime value, purchase frequency, and recency analysis.
* `gold.report_product_performance` – Sales volume, margin analysis, and category-level rollups.

## Setup & Execution

1. Clone this repository.
2. Run `scripts/bronze/proc_load_bronze.sql` to initialize staging tables and load raw CSVs.
3. Execute `scripts/silver/proc_load_silver.sql` to transform, clean, and validate records into the Silver layer.
4. Run `scripts/gold/ddl_gold.sql` to build the star schema views and analytical layers.
5. Execute tests in `tests/quality_checks.sql` to confirm data integrity across layers.
