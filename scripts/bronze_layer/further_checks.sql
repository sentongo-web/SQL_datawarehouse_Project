/*=============================================================================
SECTION 5: AUTOMATIC COLUMN PROFILE
===============================================================================

Business questions:
    For every column in every Bronze table:

    1. How many records exist?
    2. How many values are NULL?
    3. How many values are blank strings?
    4. How many different values exist?
    5. What percentage of the column is NULL?
    6. What percentage of the column is blank?

Why this matters:
    This is one of the most important Bronze-layer EDA queries.

It can reveal:
    - Completely empty columns
    - Columns with many missing values
    - Blank strings that are not stored as NULL
    - Columns with only one repeated value
    - Columns that may be expected to be unique but are not
    - Categorical columns with only a few distinct values

Important:
    This is dynamic SQL.

    Dynamic SQL means SQL Server creates the profiling query automatically
    for every column instead of us manually writing a separate query for
    every table and column.

This query only reads the data.
=============================================================================*/

DECLARE @sql NVARCHAR(MAX);

-- Build one SELECT statement for every column in every Bronze table.
SELECT
    @sql = STRING_AGG(
        CAST(
            N'
            SELECT
                N''' + REPLACE(s.name + N'.' + t.name, '''', '''''') +
                N''' AS table_name,

                ' + CAST(c.column_id AS NVARCHAR(10)) +
                N' AS column_id,

                N''' + REPLACE(c.name, '''', '''''') +
                N''' AS column_name,

                N''' + REPLACE(ty.name, '''', '''''') +
                N''' AS data_type,

                -- Count all records in the table.
                COUNT_BIG(*) AS total_rows,

                -- Count records where the current column is NULL.
                SUM(
                    CASE
                        WHEN ' + QUOTENAME(c.name) + N' IS NULL
                            THEN 1
                        ELSE 0
                    END
                ) AS null_count,

                -- Count values that are not NULL but become empty after
                -- removing spaces from the beginning and end.
                SUM(
                    CASE
                        WHEN ' + QUOTENAME(c.name) + N' IS NOT NULL
                         AND LTRIM(
                                RTRIM(
                                    CONVERT(
                                        NVARCHAR(4000),
                                        ' + QUOTENAME(c.name) + N'
                                    )
                                )
                             ) = N''''
                            THEN 1
                        ELSE 0
                    END
                ) AS blank_count,

                -- Count how many different values occur in the column.
                COUNT_BIG(
                    DISTINCT CONVERT(
                        NVARCHAR(4000),
                        ' + QUOTENAME(c.name) + N'
                    )
                ) AS distinct_count

            FROM ' +
            QUOTENAME(s.name) + N'.' + QUOTENAME(t.name)

            AS NVARCHAR(MAX)
        ),

        -- Join all the generated profiling queries together.
        N' UNION ALL '
    )
FROM sys.tables AS t
INNER JOIN sys.schemas AS s
    ON t.schema_id = s.schema_id
INNER JOIN sys.columns AS c
    ON t.object_id = c.object_id
INNER JOIN sys.types AS ty
    ON c.user_type_id = ty.user_type_id
WHERE s.name = 'bronze';

-- Add percentage calculations around the automatically generated queries.
SET @sql =
    N'
    SELECT
        table_name,
        column_id,
        column_name,
        data_type,
        total_rows,
        null_count,
        blank_count,
        distinct_count,

        -- Calculate the percentage of values that are NULL.
        CAST(
            null_count * 100.0 /
            NULLIF(total_rows, 0)
            AS DECIMAL(6,2)
        ) AS null_percentage,

        -- Calculate the percentage of values that are blank strings.
        CAST(
            blank_count * 100.0 /
            NULLIF(total_rows, 0)
            AS DECIMAL(6,2)
        ) AS blank_percentage

    FROM
    (
        ' + @sql + N'
    ) AS column_profile

    ORDER BY
        table_name,
        column_id;
    ';

-- Run the dynamically created profiling query.
EXEC sys.sp_executesql @sql;
