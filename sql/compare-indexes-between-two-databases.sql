/*
This script compares indexes between two specified Microsoft SQL Server databases. 
It identifies and lists the indexes that are present in one database but missing in the other. 
The script captures index details from the source and target databases, stores the information 
in temporary tables, and then performs a full outer join to find differences in index definitions 
between the two databases. The final output includes a detailed comparison of indexes, 
highlighting missing indexes in each database.

Steps in the Script:
1. Declare variables for the source and target database names.
2. Drop existing temporary tables if they exist.
3. Create temporary tables to store index information for both databases.
4. Capture index details from the source database and insert them into a temporary table.
5. Capture index details from the target database and insert them into a temporary table.
6. Compare indexes between the source and target databases, showing differences.
7. Identify indexes present in the target database but missing in the source database.
8. Identify indexes present in the source database but missing in the target database.

For further details on comparing indexes between two MSSQL databases, you can refer to this article:
https://umbracare.net/blog/how-to-compare-indexes-between-two-mssql-databases-easily/
*/
-- Declare variables for database names
DECLARE @SourceDatabaseName NVARCHAR(128) = 'SourceDatabase';
DECLARE @TargetDatabaseName NVARCHAR(128) = 'TargetDatabase';

-- Drop temporary tables if they exist
IF OBJECT_ID('tempdb..#SourceDatabaseIndexes') IS NOT NULL
    DROP TABLE #SourceDatabaseIndexes;

IF OBJECT_ID('tempdb..#TargetDatabaseIndexes') IS NOT NULL
    DROP TABLE #TargetDatabaseIndexes;

-- Create temporary tables in the main session
CREATE TABLE #SourceDatabaseIndexes (
    SchemaName NVARCHAR(128),
    TableName NVARCHAR(128),
    IndexName NVARCHAR(128),
    IndexID INT,
    IndexType NVARCHAR(60),
    ColumnName NVARCHAR(128),
    KeyOrdinal INT,
    IsIncludedColumn BIT
);

CREATE TABLE #TargetDatabaseIndexes (
    SchemaName NVARCHAR(128),
    TableName NVARCHAR(128),
    IndexName NVARCHAR(128),
    IndexID INT,
    IndexType NVARCHAR(60),
    ColumnName NVARCHAR(128),
    KeyOrdinal INT,
    IsIncludedColumn BIT
);

-- Capture index information from the source database
PRINT 'Capturing index information from the source database...';
DECLARE @sql NVARCHAR(MAX);

SET @sql = '
USE [' + @SourceDatabaseName + '];

INSERT INTO #SourceDatabaseIndexes
SELECT 
    schema_name(t.schema_id) AS SchemaName,
    t.name AS TableName,
    i.name AS IndexName,
    i.index_id AS IndexID,
    i.type_desc AS IndexType,
    c.name AS ColumnName,
    ic.key_ordinal AS KeyOrdinal,
    ic.is_included_column AS IsIncludedColumn
FROM sys.indexes i
INNER JOIN sys.index_columns ic ON i.object_id = ic.object_id AND i.index_id = ic.index_id
INNER JOIN sys.columns c ON ic.object_id = c.object_id AND ic.column_id = c.column_id
INNER JOIN sys.tables t ON i.object_id = t.object_id
WHERE i.is_hypothetical = 0
ORDER BY SchemaName, TableName, IndexName, KeyOrdinal;
';

EXEC sp_executesql @sql;

-- Capture index information from the target database
PRINT 'Capturing index information from the target database...';

SET @sql = '
USE [' + @TargetDatabaseName + '];

INSERT INTO #TargetDatabaseIndexes
SELECT 
    schema_name(t.schema_id) AS SchemaName,
    t.name AS TableName,
    i.name AS IndexName,
    i.index_id AS IndexID,
    i.type_desc AS IndexType,
    c.name AS ColumnName,
    ic.key_ordinal AS KeyOrdinal,
    ic.is_included_column AS IsIncludedColumn
FROM sys.indexes i
INNER JOIN sys.index_columns ic ON i.object_id = ic.object_id AND i.index_id = ic.index_id
INNER JOIN sys.columns c ON ic.object_id = c.object_id AND ic.column_id = c.column_id
INNER JOIN sys.tables t ON i.object_id = t.object_id
WHERE i.is_hypothetical = 0
ORDER BY SchemaName, TableName, IndexName, KeyOrdinal;
';

EXEC sp_executesql @sql;

-- Compare indexes between the source and target databases
PRINT 'Comparing indexes between the source and target databases...';
PRINT 'Comparison of Indexes:';
SELECT 
    COALESCE(s.SchemaName, t.SchemaName) AS SchemaName,
    COALESCE(s.TableName, t.TableName) AS TableName,
    COALESCE(s.IndexName, t.IndexName) AS IndexName,
    COALESCE(s.IndexID, t.IndexID) AS IndexID,
    s.IndexType AS SourceIndexType,
    t.IndexType AS TargetIndexType,
    s.ColumnName AS SourceColumnName,
    t.ColumnName AS TargetColumnName,
    s.KeyOrdinal AS SourceKeyOrdinal,
    t.KeyOrdinal AS TargetKeyOrdinal,
    s.IsIncludedColumn AS SourceIsIncludedColumn,
    t.IsIncludedColumn AS TargetIsIncludedColumn
FROM #SourceDatabaseIndexes s
FULL OUTER JOIN #TargetDatabaseIndexes t 
ON s.SchemaName = t.SchemaName
AND s.TableName = t.TableName
AND s.IndexName = t.IndexName
AND s.IndexID = t.IndexID
AND s.ColumnName = t.ColumnName
ORDER BY SchemaName, TableName, IndexName;

-- Identify missing indexes in the source database
PRINT 'Identifying missing indexes in the source database...';
PRINT 'Indexes present in the target database but missing in the source database:';
SELECT 
    t.SchemaName,
    t.TableName,
    t.IndexName,
    t.IndexID,
    t.IndexType,
    t.ColumnName,
    t.KeyOrdinal,
    t.IsIncludedColumn
FROM #TargetDatabaseIndexes t
LEFT JOIN #SourceDatabaseIndexes s
ON t.SchemaName = s.SchemaName
AND t.TableName = s.TableName
AND t.IndexName = s.IndexName
AND t.IndexID = s.IndexID
AND t.ColumnName = s.ColumnName
WHERE s.IndexName IS NULL
ORDER BY t.SchemaName, t.TableName, t.IndexName;

-- Identify missing indexes in the target database
PRINT 'Identifying missing indexes in the target database...';
PRINT 'Indexes present in the source database but missing in the target database:';
SELECT 
    s.SchemaName,
    s.TableName,
    s.IndexName,
    s.IndexID,
    s.IndexType,
    s.ColumnName,
    s.KeyOrdinal,
    s.IsIncludedColumn
FROM #SourceDatabaseIndexes s
LEFT JOIN #TargetDatabaseIndexes t
ON s.SchemaName = t.SchemaName
AND s.TableName = t.TableName
AND s.IndexName = t.IndexName
AND s.IndexID = t.IndexID
AND s.ColumnName = t.ColumnName
WHERE t.IndexName IS NULL
ORDER BY s.SchemaName, s.TableName, s.IndexName;
