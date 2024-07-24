/*
Filename: sync-indexes-source-to-target-database.sql

This T-SQL script synchronizes non-clustered indexes between two databases: SourceDatabase and TargetDatabase.
The script performs the following tasks:
1. Collects non-clustered index information from both the SourceDatabase and TargetDatabase.
2. Compares indexes based on their structure (key columns and included columns), ignoring index names.
3. Identifies indexes that exist in the SourceDatabase but not in the TargetDatabase and generates scripts to add these indexes to the TargetDatabase.
4. Identifies indexes that exist in the TargetDatabase but not in the SourceDatabase and generates scripts to remove these indexes from the TargetDatabase.
5. Prints the generated scripts for adding and removing indexes, which can be copied and executed on the TargetDatabase.

Detailed Comparison Strategy:
1. **Index Definition Collection**:
   - For both SourceDatabase and TargetDatabase, the script collects details about non-clustered indexes.
   - These details include the table name, index name, key columns, and included columns.
   - Key columns and included columns are collected separately to accurately capture the index structure.
2. **Index Comparison Strategy**:
   - The script compares indexes based on their structure (key columns and included columns) rather than their names.
   - Two indexes are considered identical if:
       - They are on the same table.
       - They have identical key columns in the same order.
       - They have identical included columns in the same order.
   - Index names are ignored in the comparison of structures.
3. **Identifying Indexes to Add**:
   - Indexes that exist in SourceDatabase but not in TargetDatabase are identified based on their structure.
   - A CREATE INDEX script is generated for each index that needs to be added.
4. **Identifying Indexes to Remove**:
   - Indexes that exist in TargetDatabase but not in SourceDatabase are identified based on their structure.
   - A DROP INDEX script is generated for each index that needs to be removed.
5. **Generating Scripts**:
   - The generated scripts for adding and removing indexes are printed in a format that you can easily copy and paste for execution on the TargetDatabase.
*/

-- Declare database names
DECLARE @SourceDatabase NVARCHAR(128) = 'SourceDatabase';
DECLARE @TargetDatabase NVARCHAR(128) = 'TargetDatabase';

-- Temporary tables to store index information
IF OBJECT_ID('tempdb..#SourceIndexes') IS NOT NULL DROP TABLE #SourceIndexes;
IF OBJECT_ID('tempdb..#TargetIndexes') IS NOT NULL DROP TABLE #TargetIndexes;
IF OBJECT_ID('tempdb..#IndexesToAdd') IS NOT NULL DROP TABLE #IndexesToAdd;
IF OBJECT_ID('tempdb..#IndexesToRemove') IS NOT NULL DROP TABLE #IndexesToRemove;

CREATE TABLE #SourceIndexes (
    TableName NVARCHAR(128),
    IndexName NVARCHAR(128),
    IndexColumns NVARCHAR(MAX),
    IncludedColumns NVARCHAR(MAX)
);

CREATE TABLE #TargetIndexes (
    TableName NVARCHAR(128),
    IndexName NVARCHAR(128),
    IndexColumns NVARCHAR(MAX),
    IncludedColumns NVARCHAR(MAX)
);

CREATE TABLE #IndexesToAdd (
    TableName NVARCHAR(128),
    IndexName NVARCHAR(128),
    CreateScript NVARCHAR(MAX)
);

CREATE TABLE #IndexesToRemove (
    TableName NVARCHAR(128),
    IndexName NVARCHAR(128),
    DropScript NVARCHAR(MAX)
);

-- Collect index information from SourceDatabase
DECLARE @sql NVARCHAR(MAX);

-- Collect non-clustered index details from the SourceDatabase
-- Separate key columns and included columns
SET @sql = '
USE ' + QUOTENAME(@SourceDatabase) + ';
SELECT 
    t.name AS TableName,
    i.name AS IndexName,
    STUFF((
        SELECT '','' + QUOTENAME(c.name)
        FROM sys.index_columns ic
        JOIN sys.columns c ON ic.object_id = c.object_id AND ic.column_id = c.column_id
        WHERE ic.object_id = t.object_id AND ic.index_id = i.index_id AND ic.is_included_column = 0
        ORDER BY ic.key_ordinal
        FOR XML PATH(''''), TYPE
    ).value(''.'', ''NVARCHAR(MAX)''), 1, 1, '''') AS IndexColumns,
    ISNULL(STUFF((
        SELECT '','' + QUOTENAME(c.name)
        FROM sys.index_columns ic
        JOIN sys.columns c ON ic.object_id = c.object_id AND ic.column_id = c.column_id
        WHERE ic.object_id = t.object_id AND ic.index_id = i.index_id AND ic.is_included_column = 1
        ORDER BY ic.index_column_id
        FOR XML PATH(''''), TYPE
    ).value(''.'', ''NVARCHAR(MAX)''), 1, 1, ''''), '''') AS IncludedColumns
FROM 
    sys.indexes i
JOIN 
    sys.tables t ON i.object_id = t.object_id
JOIN 
    sys.schemas s ON t.schema_id = s.schema_id
WHERE 
    i.type = 2 AND i.is_primary_key = 0 AND i.is_unique_constraint = 0;
';

INSERT INTO #SourceIndexes (TableName, IndexName, IndexColumns, IncludedColumns)
EXEC sp_executesql @sql;

-- Collect index information from TargetDatabase
SET @sql = '
USE ' + QUOTENAME(@TargetDatabase) + ';
SELECT 
    t.name AS TableName,
    i.name AS IndexName,
    STUFF((
        SELECT '','' + QUOTENAME(c.name)
        FROM sys.index_columns ic
        JOIN sys.columns c ON ic.object_id = c.object_id AND ic.column_id = c.column_id
        WHERE ic.object_id = t.object_id AND ic.index_id = i.index_id AND ic.is_included_column = 0
        ORDER BY ic.key_ordinal
        FOR XML PATH(''''), TYPE
    ).value(''.'', ''NVARCHAR(MAX)''), 1, 1, '''') AS IndexColumns,
    ISNULL(STUFF((
        SELECT '','' + QUOTENAME(c.name)
        FROM sys.index_columns ic
        JOIN sys.columns c ON ic.object_id = c.object_id AND ic.column_id = c.column_id
        WHERE ic.object_id = t.object_id AND ic.index_id = i.index_id AND ic.is_included_column = 1
        ORDER BY ic.index_column_id
        FOR XML PATH(''''), TYPE
    ).value(''.'', ''NVARCHAR(MAX)''), 1, 1, ''''), '''') AS IncludedColumns
FROM 
    sys.indexes i
JOIN 
    sys.tables t ON i.object_id = t.object_id
JOIN 
    sys.schemas s ON t.schema_id = s.schema_id
WHERE 
    i.type = 2 AND i.is_primary_key = 0 AND i.is_unique_constraint = 0;
';

INSERT INTO #TargetIndexes (TableName, IndexName, IndexColumns, IncludedColumns)
EXEC sp_executesql @sql;

-- Find indexes to add to TargetDatabase
-- Compare based on IndexColumns and IncludedColumns, ignoring index names
INSERT INTO #IndexesToAdd (TableName, IndexName, CreateScript)
SELECT 
    si.TableName, 
    si.IndexName, 
    'CREATE NONCLUSTERED INDEX ' + QUOTENAME(si.IndexName) + ' ON ' + QUOTENAME(si.TableName) + ' (' + si.IndexColumns + ')' +
    CASE WHEN si.IncludedColumns <> '' THEN ' INCLUDE (' + si.IncludedColumns + ')' ELSE '' END AS CreateScript
FROM #SourceIndexes si
LEFT JOIN #TargetIndexes ti 
ON si.TableName = ti.TableName AND si.IndexColumns = ti.IndexColumns AND si.IncludedColumns = ti.IncludedColumns
WHERE ti.IndexName IS NULL;

-- Find indexes to remove from TargetDatabase
-- Compare based on IndexColumns and IncludedColumns, ignoring index names
INSERT INTO #IndexesToRemove (TableName, IndexName, DropScript)
SELECT 
    ti.TableName, 
    ti.IndexName, 
    'DROP INDEX ' + QUOTENAME(ti.IndexName) + ' ON ' + QUOTENAME(ti.TableName) AS DropScript
FROM #TargetIndexes ti
LEFT JOIN #SourceIndexes si 
ON ti.TableName = si.TableName AND ti.IndexColumns = si.IndexColumns AND ti.IncludedColumns = si.IncludedColumns
WHERE si.IndexName IS NULL;

-- Display report
PRINT 'Indexes to Add:';
SELECT * FROM #IndexesToAdd;

PRINT 'Indexes to Remove:';
SELECT * FROM #IndexesToRemove;

-- Generate scripts for adding indexes
DECLARE @CreateScript NVARCHAR(MAX);

PRINT '--- Indexes to Add ---';
-- Generate and print script to add indexes
DECLARE AddCursor CURSOR FOR
SELECT CreateScript FROM #IndexesToAdd;

OPEN AddCursor;
FETCH NEXT FROM AddCursor INTO @CreateScript;
WHILE @@FETCH_STATUS = 0
BEGIN
    PRINT @CreateScript;
    FETCH NEXT FROM AddCursor INTO @CreateScript;
END;
CLOSE AddCursor;
DEALLOCATE AddCursor;

PRINT '--- Indexes to Remove ---';
-- Generate and print script to remove indexes
DECLARE @DropScript NVARCHAR(MAX);

DECLARE RemoveCursor CURSOR FOR
SELECT DropScript FROM #IndexesToRemove;

OPEN RemoveCursor;
FETCH NEXT FROM RemoveCursor INTO @DropScript;
WHILE @@FETCH_STATUS = 0
BEGIN
    PRINT @DropScript;
    FETCH NEXT FROM RemoveCursor INTO @DropScript;
END;
CLOSE RemoveCursor;
DEALLOCATE RemoveCursor;
