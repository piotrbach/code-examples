/*
Filename: analyze-and-drop-inefficient-indexes.sql

This T-SQL script analyzes existing non-clustered indexes in the specified database and identifies those that are inefficient or little-used.
The script generates `DROP INDEX` commands for indexes that meet the criteria for inefficiency or low usage. The criteria used for analysis include:
1. Indexes with low seek, scan, and lookup counts.
2. Indexes with high update counts relative to their usage.
3. Indexes that have been recently created and have low usage.

The generated `DROP INDEX` commands are returned along with key statistics so they can be reviewed before execution.

Criteria for Identifying Inefficient Indexes:
1. **Low Usage**:
   - Indexes with a low number of seeks, scans, and lookups, indicating that they are rarely used in query execution.
2. **High Maintenance**:
   - Indexes with a high number of updates relative to their usage, indicating that they incur a high maintenance cost.
3. **Recently Created Indexes with Low Usage**:
   - Indexes that were recently created but have not been used frequently, suggesting that they may not be beneficial.

The script collects information from the following system DMVs:
- sys.dm_db_index_usage_stats: Provides statistics about index usage.
- sys.indexes: Provides metadata about indexes.
- sys.tables: Provides metadata about tables.
- sys.schemas: Provides metadata about schemas.

The generated `DROP INDEX` commands along with key statistics are returned for review.
*/

-- Declare database name
DECLARE @DatabaseName NVARCHAR(128) = 'YourDatabaseName';

-- Check if the database exists
IF NOT EXISTS (SELECT * FROM sys.databases WHERE name = @DatabaseName)
BEGIN
    RAISERROR('Database "%s" does not exist.', 16, 1, @DatabaseName);
    RETURN;
END

-- Temporary table to store index analysis information
IF OBJECT_ID('tempdb..#IndexAnalysis') IS NOT NULL DROP TABLE #IndexAnalysis;

CREATE TABLE #IndexAnalysis (
    SchemaName NVARCHAR(128),
    TableName NVARCHAR(128),
    IndexName NVARCHAR(128),
    IndexType NVARCHAR(128),
    UserSeeks BIGINT,
    UserScans BIGINT,
    UserLookups BIGINT,
    UserUpdates BIGINT,
    LastUserSeek DATETIME,
    LastUserScan DATETIME,
    LastUserLookup DATETIME,
    LastUserUpdate DATETIME,
    IndexCreationDate DATETIME,
    Benefit FLOAT,
    DropScript NVARCHAR(MAX)
);

-- Collect index usage statistics
INSERT INTO #IndexAnalysis (SchemaName, TableName, IndexName, IndexType, UserSeeks, UserScans, UserLookups, UserUpdates, LastUserSeek, LastUserScan, LastUserLookup, LastUserUpdate, IndexCreationDate, Benefit, DropScript)
SELECT 
    s.name AS SchemaName,
    t.name AS TableName,
    i.name AS IndexName,
    CASE WHEN i.type_desc = 'NONCLUSTERED' THEN 'NONCLUSTERED' ELSE 'UNKNOWN' END AS IndexType,
    ISNULL(us.user_seeks, 0) AS UserSeeks,
    ISNULL(us.user_scans, 0) AS UserScans,
    ISNULL(us.user_lookups, 0) AS UserLookups,
    ISNULL(us.user_updates, 0) AS UserUpdates,
    us.last_user_seek AS LastUserSeek,
    us.last_user_scan AS LastUserScan,
    us.last_user_lookup AS LastUserLookup,
    us.last_user_update AS LastUserUpdate,
    o.create_date AS IndexCreationDate,
    CASE 
        WHEN ISNULL(us.user_seeks, 0) + ISNULL(us.user_scans, 0) + ISNULL(us.user_lookups, 0) = 0 THEN 0 
        ELSE CAST(100.0 * (ISNULL(us.user_seeks, 0) + ISNULL(us.user_scans, 0) + ISNULL(us.user_lookups, 0)) / 
            (ISNULL(us.user_seeks, 0) + ISNULL(us.user_scans, 0) + ISNULL(us.user_lookups, 0) + ISNULL(us.user_updates, 0)) AS FLOAT) 
    END AS Benefit,
    'DROP INDEX ' + QUOTENAME(i.name) + ' ON ' + QUOTENAME(s.name) + '.' + QUOTENAME(t.name) AS DropScript
FROM 
    sys.indexes i WITH (NOLOCK)
JOIN 
    sys.tables t WITH (NOLOCK) ON i.object_id = t.object_id
JOIN 
    sys.schemas s WITH (NOLOCK) ON t.schema_id = s.schema_id
JOIN 
    sys.objects o WITH (NOLOCK) ON i.object_id = o.object_id AND o.type = 'U' -- Ensure to get user tables
LEFT JOIN 
    sys.dm_db_index_usage_stats us WITH (NOLOCK) ON i.object_id = us.object_id AND i.index_id = us.index_id AND us.database_id = DB_ID(@DatabaseName)
WHERE 
    i.type = 2 -- Nonclustered indexes only
    AND i.is_primary_key = 0 -- Exclude primary keys
    AND i.is_unique_constraint = 0 -- Exclude unique constraints
    AND t.is_ms_shipped = 0 -- Exclude system tables
    AND (ISNULL(us.user_seeks, 0) + ISNULL(us.user_scans, 0) + ISNULL(us.user_lookups, 0) > 0) -- Exclude indexes with no activity
ORDER BY 
    ISNULL(us.user_seeks, 0) + ISNULL(us.user_scans, 0) + ISNULL(us.user_lookups, 0) ASC, -- Low usage first
    ISNULL(us.user_updates, 0) DESC; -- High maintenance first

-- Select indexes for review
SELECT 
    SchemaName,
    TableName,
    IndexName,
    IndexType,
    UserSeeks,
    UserScans,
    UserLookups,
    UserUpdates,
    LastUserSeek,
    LastUserScan,
    LastUserLookup,
    LastUserUpdate,
    IndexCreationDate,
    Benefit,
    DropScript
FROM #IndexAnalysis
WHERE (ISNULL(UserSeeks, 0) + ISNULL(UserScans, 0) + ISNULL(UserLookups, 0)) < 100 -- Low usage threshold
   OR ISNULL(UserUpdates, 0) > 1000 -- High maintenance threshold
   OR (IndexCreationDate > DATEADD(MONTH, -3, GETDATE()) AND (ISNULL(UserSeeks, 0) + ISNULL(UserScans, 0) + ISNULL(UserLookups, 0)) < 10); -- Recently created with low usage

-- Clean up
DROP TABLE #IndexAnalysis;
