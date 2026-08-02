/*=============================================================================
CONFIRM THAT THE GOLD VIEWS EXIST
=============================================================================*/

SELECT
    s.name AS schema_name,
    v.name AS view_name,
    v.create_date,
    v.modify_date
FROM sys.views AS v
INNER JOIN sys.schemas AS s
    ON v.schema_id = s.schema_id
WHERE s.name = 'gold'
ORDER BY v.name;
