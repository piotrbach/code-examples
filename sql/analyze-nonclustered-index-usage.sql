/*
Filename: analyze-nonclustered-index-usage.sql

This T-SQL script analyzes the usage of non-clustered indexes on individual tables and returns key statistics.
The script helps to identify the efficiency of data fetching, adding, deleting, and modifying operations by examining the usage patterns of non-clustered indexes.

The script collects information from the following system DMVs:
- sys.dm_db_index_usage_stats: Provides statistics about index usage.
- sys.dm_db_index_operational_stats: Provides operational statistics about index maintenance.
- sys.indexes: Provides metadata about indexes.
- sys.tables: Provides metadata about tables.
- sys.schemas: Provides metadata about schemas.
- sys.index_columns and sys.columns: Provides details about index included columns.

The key statistics include:
- User seeks, scans, lookups, and updates.
- System seeks, scans, lookups, and updates.
- Last user seek, scan, lookup, and update times.
- Index operational statistics (leaf_insert_count, leaf_update_count, leaf_delete_count).
- Included columns in the indexes.

The results are returned for review to help understand the efficiency of index usage on individual tables.
*/

-- Declare database name and monitoring period variables
DECLARE @DatabaseName NVARCHAR(128) = 'YourDatabaseName';
DECLARE @MonitoringValue INT = 3; -- The numeric value of the monitoring period
DECLARE @MonitoringUnit NVARCHAR(50) = 'DAYS'; -- Valid units: 'MINUTES', 'HOURS', 'DAYS', 'MONTHS', 'YEARS'

-- Check if the database exists
IF NOT EXISTS (SELECT * FROM sys.databases WHERE name = @DatabaseName)
BEGIN
    RAISERROR('Database "%s" does not exist.', 16, 1, @DatabaseName);
    RETURN;
END

-- Set the monitoring period
DECLARE @StartTime DATETIME;
IF @MonitoringUnit = 'MINUTES'
    SET @StartTime = DATEADD(MINUTE, -@MonitoringValue, GETDATE());
ELSE IF @MonitoringUnit = 'HOURS'
    SET @StartTime = DATEADD(HOUR, -@MonitoringValue, GETDATE());
ELSE IF @MonitoringUnit = 'DAYS'
    SET @StartTime = DATEADD(DAY, -@MonitoringValue, GETDATE());
ELSE IF @MonitoringUnit = 'MONTHS'
    SET @StartTime = DATEADD(MONTH, -@MonitoringValue, GETDATE());
ELSE IF @MonitoringUnit = 'YEARS'
    SET @StartTime = DATEADD(YEAR, -@MonitoringValue, GETDATE());
ELSE
BEGIN
    RAISERROR('Invalid monitoring unit specified.', 16, 1);
    RETURN;
END

-- Temporary table to store index analysis information
IF OBJECT_ID('tempdb..#IndexUsageStats') IS NOT NULL DROP TABLE #IndexUsageStats;

CREATE TABLE #IndexUsageStats (
    SchemaName NVARCHAR(128),
    TableName NVARCHAR(128),
    IndexName NVARCHAR(128),
    IndexType NVARCHAR(128),
    IncludedColumns NVARCHAR(MAX),
    UserSeeks BIGINT,
    UserScans BIGINT,
    UserLookups BIGINT,
    UserUpdates BIGINT,
    SystemSeeks BIGINT,
    SystemScans BIGINT,
    SystemLookups BIGINT,
    SystemUpdates BIGINT,
    LastUserSeek DATETIME,
    LastUserScan DATETIME,
    LastUserLookup DATETIME,
    LastUserUpdate DATETIME,
    LastSystemSeek DATETIME,
    LastSystemScan DATETIME,
    LastSystemLookup DATETIME,
    LastSystemUpdate DATETIME,
    LeafInsertCount BIGINT,
    LeafUpdateCount BIGINT,
    LeafDeleteCount BIGINT
);

-- Collect index usage statistics
INSERT INTO #IndexUsageStats (SchemaName, TableName, IndexName, IndexType, IncludedColumns, UserSeeks, UserScans, UserLookups, UserUpdates, SystemSeeks, SystemScans, SystemLookups, SystemUpdates, LastUserSeek, LastUserScan, LastUserLookup, LastUserUpdate, LastSystemSeek, LastSystemScan, LastSystemLookup, LastSystemUpdate, LeafInsertCount, LeafUpdateCount, LeafDeleteCount)
SELECT 
    s.name AS SchemaName,
    t.name AS TableName,
    i.name AS IndexName,
    CASE WHEN i.type_desc = 'NONCLUSTERED' THEN 'NONCLUSTERED' ELSE 'UNKNOWN' END AS IndexType,
    STUFF((
        SELECT ', ' + c.name
        FROM sys.index_columns ic
        JOIN sys.columns c ON ic.object_id = c.object_id AND ic.column_id = c.column_id
        WHERE ic.object_id = i.object_id AND ic.index_id = i.index_id AND ic.is_included_column = 1
        FOR XML PATH(''), TYPE
    ).value('.', 'NVARCHAR(MAX)'), 1, 2, '') AS IncludedColumns,
    ISNULL(us.user_seeks, 0) AS UserSeeks,
    ISNULL(us.user_scans, 0) AS UserScans,
    ISNULL(us.user_lookups, 0) AS UserLookups,
    ISNULL(us.user_updates, 0) AS UserUpdates,
    ISNULL(us.system_seeks, 0) AS SystemSeeks,
    ISNULL(us.system_scans, 0) AS SystemScans,
    ISNULL(us.system_lookups, 0) AS SystemLookups,
    ISNULL(us.system_updates, 0) AS SystemUpdates,
    us.last_user_seek AS LastUserSeek,
    us.last_user_scan AS LastUserScan,
    us.last_user_lookup AS LastUserLookup,
    us.last_user_update AS LastUserUpdate,
    us.last_system_seek AS LastSystemSeek,
    us.last_system_scan AS LastSystemScan,
    us.last_system_lookup AS LastSystemLookup,
    us.last_system_update AS LastSystemUpdate,
    ISNULL(os.leaf_insert_count, 0) AS LeafInsertCount,
    ISNULL(os.leaf_update_count, 0) AS LeafUpdateCount,
    ISNULL(os.leaf_delete_count, 0) AS LeafDeleteCount
FROM 
    sys.indexes i WITH (NOLOCK)
JOIN 
    sys.tables t WITH (NOLOCK) ON i.object_id = t.object_id
JOIN 
    sys.schemas s WITH (NOLOCK) ON t.schema_id = s.schema_id
LEFT JOIN 
    sys.dm_db_index_usage_stats us WITH (NOLOCK) ON i.object_id = us.object_id AND i.index_id = us.index_id AND us.database_id = DB_ID(@DatabaseName)
CROSS APPLY 
    sys.dm_db_index_operational_stats(DB_ID(@DatabaseName), t.object_id, i.index_id, NULL) os
WHERE 
    i.type = 2 -- Nonclustered indexes only
    AND i.is_primary_key = 0 -- Exclude primary keys
    AND i.is_unique_constraint = 0 -- Exclude unique constraints
    AND t.is_ms_shipped = 0 -- Exclude system tables
    AND (
        us.last_user_seek >= @StartTime OR
        us.last_user_scan >= @StartTime OR
        us.last_user_lookup >= @StartTime OR
        us.last_user_update >= @StartTime OR
        us.last_system_seek >= @StartTime OR
        us.last_system_scan >= @StartTime OR
        us.last_system_lookup >= @StartTime OR
        us.last_system_update >= @StartTime
    )
ORDER BY 
    s.name, t.name, i.name;

-- Select indexes for review
SELECT 
    SchemaName,
    TableName,
    IndexName,
    IndexType,
    IncludedColumns,
    UserSeeks,
    UserScans,
    UserLookups,
    UserUpdates,
    SystemSeeks,
    SystemScans,
    SystemLookups,
    SystemUpdates,
    LastUserSeek,
    LastUserScan,
    LastUserLookup,
    LastUserUpdate,
    LastSystemSeek,
    LastSystemScan,
    LastSystemLookup,
    LastSystemUpdate,
    LeafInsertCount,
    LeafUpdateCount,
    LeafDeleteCount
FROM #IndexUsageStats
ORDER BY SchemaName, TableName, IndexName;

-- Clean up
DROP TABLE #IndexUsageStats;
