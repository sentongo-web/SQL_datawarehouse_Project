# Data Model Design

This document explains the design decisions behind the Gold layer's dimensional model — the part of the project that turns cleaned Silver data into something a business user or a BI tool can actually query without needing to understand joins across six source tables.

## Choosing a business process and a grain

The only business process in this dataset is **sales**: a customer buys a product on a given date. Before writing any DDL, the first decision a dimensional model needs is the grain — what does one row in the fact table represent?

Here, the grain of `gold.fact_sales` is **one row per sales order line**. An order can contain several products, so the same `order_number` can appear on multiple rows. This matters because it rules out treating `order_number` as a primary key — it isn't one, and none of the queries in this project assume it is.

## Why a star schema, not a snowflake or a flat table

Three options were on the table:

- **A single flat table** (everything pre-joined) — fastest to query, but it duplicates customer and product attributes on every sales row and makes the model harder to extend if a new fact (returns, inventory) is added later.
- **A snowflake schema** (dimensions normalized into sub-dimensions, e.g. splitting `dim_products` into product + category + subcategory tables) — reduces redundancy but adds joins that most BI tools and analysts don't need for a dataset this size.
- **A star schema** — one fact table surrounded by denormalized dimensions.

The star schema won because the audience for the Gold layer is analytics and reporting, not another round of transactional normalization. Two dimensions (customers, products) and one fact (sales) is small enough that snowflaking would add join overhead for no real benefit, and it's the layout every common BI tool (Power BI, Tableau, Looker) is built to consume directly.

## The three tables

**`gold.dim_customers`** — one row per customer. Built from `silver.crm_cust_info` as the identity source, enriched with birth date and gender from `silver.erp_cust_az12` and country from `silver.erp_loc_a101`. CRM gender wins over ERP gender when both exist, since CRM is the system closer to the actual sales relationship.

**`gold.dim_products`** — one row per *currently active* product. `silver.crm_prd_info` keeps every historical version of a product (a new row is written whenever a price or line changes), so the Gold view filters down to the row where `prd_end_dt IS NULL` — the current version — and enriches it with category and subcategory from `silver.erp_px_cat_g1v2`.

**`gold.fact_sales`** — one row per sales order line, holding the two dimension keys plus the order/ship/due dates and the sales/quantity/price measures. It only ever reads from Silver and the two dimension views above; nothing downstream reads from Bronze or Silver directly, which keeps the Gold layer the single, stable contract for reporting.

## Keys: what's implemented now, and the tradeoff behind it

Both dimensions expose a `_key` column that fact rows join on. Right now that key is the natural identifier (`cst_id` / `prd_id`) cast to `BIGINT`, not a generated surrogate key from an `IDENTITY` column. That's a deliberate tradeoff, not an oversight:

- The Gold layer is implemented as **views**, not physical tables, so there's nowhere to persist an `IDENTITY` value between refreshes — a `ROW_NUMBER()`-based key would silently change every time a new customer or product is added upstream of it, breaking any historical fact rows already joined to it.
- Using the natural ID as the key keeps it stable across refreshes at the cost of the usual reasons teams use surrogate keys — most importantly, tracking attribute history (SCD Type 2) for customers.

Products already get partial history handling: `silver.crm_prd_info` keeps every version of a product with `prd_start_dt`/`prd_end_dt` boundaries computed with `LEAD()`, so a product's price or category history is preserved in Silver even though Gold only exposes the current version. Customers don't have that yet — `dim_customers` only reflects the latest known state. If this warehouse were promoted to production, the natural next step is converting the two dimensions into physical tables with `IDENTITY` surrogate keys and a proper SCD Type 2 pattern (`dwh_valid_from` / `dwh_valid_to` / `dwh_is_current`) on `dim_customers`, loaded by a real dimension-load procedure instead of a view.

## Handling missing dimension matches

A sales row can reference a customer or product that doesn't exist in the current dimension (deleted upstream, bad key, timing mismatch between source systems). Rather than leaving a `NULL` foreign key — which silently breaks `INNER JOIN`s and undercounts totals in any downstream report — both dimensions include an explicit **Unknown member** row with key `-1`, and `fact_sales` maps any unmatched row to it via `COALESCE`. Every fact row always has a valid, joinable key, and "how much revenue has no matching customer" becomes a normal filter (`WHERE customer_key = -1`) instead of a silent gap.

## Relationships

```
dim_customers (1) ───< fact_sales >─── (1) dim_products
                     customer_key         product_key
```

Both relationships are one-to-many from dimension to fact, enforced logically (not with physical foreign keys, since these are views) and verified by the referential-integrity checks in `tests/gold_checks.sql`.

## Where this lives in the repo

- Implementation: [`scripts/gold_layer/ddl_gold.sql`](../scripts/gold_layer/ddl_gold.sql)
- Column-level reference: [`docs/data_catalog.md`](data_catalog.md)
- Diagram: [`docs/model_images/data_model star schema.png`](model_images/data_model%20star%20schema.png)
- Integrity checks: [`tests/gold_checks.sql`](../tests/gold_checks.sql)
