-- Description:
-- This script removes indexes from a specified SQL Server database.
-- It first drops any foreign key constraints that depend on the indexes,
-- then it drops the indexes themselves. The script includes checks to
-- ensure that it only attempts to drop existing constraints and indexes.

-- Variables to specify the database name, schema name, and index type
DECLARE @DatabaseName NVARCHAR(128) = 'YOUR-DATABASE';  -- Replace with your database name
DECLARE @SchemaName NVARCHAR(128) = 'dbo'; -- Default schema is 'dbo'
DECLARE @IndexType NVARCHAR(128) = 'NONCLUSTERED';  -- Index type can be 'NONCLUSTERED', 'CLUSTERED', or 'ALL'

-- Temporary table to store index and constraint information
CREATE TABLE #IndexesToRemove (
    TableName NVARCHAR(128),
    IndexName NVARCHAR(128),
    IndexType NVARCHAR(128),
    ConstraintName NVARCHAR(128),
    ConstraintTable NVARCHAR(128)
);

-- Dynamic SQL to populate the temporary table with index and constraint information
DECLARE @SQL NVARCHAR(MAX) = '
USE ' + QUOTENAME(@DatabaseName) + ';
INSERT INTO #IndexesToRemove (TableName, IndexName, IndexType, ConstraintName, ConstraintTable)
SELECT 
    t.name AS TableName,
    i.name AS IndexName,
    i.type_desc AS IndexType,
    fk.name AS ConstraintName,
    OBJECT_NAME(fkc.parent_object_id) AS ConstraintTable
FROM 
    sys.indexes i
    JOIN sys.tables t ON i.object_id = t.object_id
    JOIN sys.schemas s ON t.schema_id = s.schema_id
    LEFT JOIN sys.foreign_keys fk ON i.object_id = fk.referenced_object_id
    LEFT JOIN sys.foreign_key_columns fkc ON fk.object_id = fkc.constraint_object_id
WHERE 
    s.name = @SchemaName AND
    (
        @IndexType = ''ALL'' OR
        (i.type = 1 AND @IndexType = ''CLUSTERED'') OR
        (i.type = 2 AND @IndexType = ''NONCLUSTERED'')
    )
';

-- Execute the dynamic SQL to populate the temporary table
EXEC sp_executesql @SQL, N'@SchemaName NVARCHAR(128), @IndexType NVARCHAR(128)', @SchemaName, @IndexType;

-- Temporary table to store constraints that need to be dropped
CREATE TABLE #ConstraintsToRemove (
    ConstraintName NVARCHAR(128),
    ConstraintTable NVARCHAR(128),
    SchemaName NVARCHAR(128)
);

-- Populate the temporary table with constraints that need to be dropped
INSERT INTO #ConstraintsToRemove (ConstraintName, ConstraintTable, SchemaName)
SELECT DISTINCT ConstraintName, ConstraintTable, @SchemaName
FROM #IndexesToRemove
WHERE ConstraintName IS NOT NULL;

-- Cursor to iterate over the constraints to be removed
DECLARE @CurrentConstraintName NVARCHAR(128);
DECLARE @CurrentConstraintTable NVARCHAR(128);
DECLARE @DropConstraintSQL NVARCHAR(MAX);

DECLARE ConstraintCursor CURSOR FOR
SELECT ConstraintName, ConstraintTable FROM #ConstraintsToRemove;

OPEN ConstraintCursor;
FETCH NEXT FROM ConstraintCursor INTO @CurrentConstraintName, @CurrentConstraintTable;

WHILE @@FETCH_STATUS = 0
BEGIN
    -- Ensure the constraint exists before attempting to drop it
    IF EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = @CurrentConstraintName AND parent_object_id = OBJECT_ID(@SchemaName + '.' + @CurrentConstraintTable))
    BEGIN
        -- Drop the foreign key constraint
        SET @DropConstraintSQL = 'ALTER TABLE ' + QUOTENAME(@SchemaName) + '.' + QUOTENAME(@CurrentConstraintTable) + ' DROP CONSTRAINT ' + QUOTENAME(@CurrentConstraintName);
        EXEC sp_executesql @DropConstraintSQL;
        PRINT 'Dropped foreign key constraint ' + @CurrentConstraintName + ' on table ' + @CurrentConstraintTable;
    END
    ELSE
    BEGIN
        PRINT 'Constraint ' + @CurrentConstraintName + ' does not exist on table ' + @CurrentConstraintTable;
    END

    FETCH NEXT FROM ConstraintCursor INTO @CurrentConstraintName, @CurrentConstraintTable;
END

CLOSE ConstraintCursor;
DEALLOCATE ConstraintCursor;

-- Cursor to iterate over the indexes to be removed
DECLARE @TableName NVARCHAR(128);
DECLARE @IndexName NVARCHAR(128);
DECLARE @DropIndexSQL NVARCHAR(MAX);

DECLARE IndexCursor CURSOR FOR
SELECT DISTINCT TableName, IndexName FROM #IndexesToRemove;

OPEN IndexCursor;
FETCH NEXT FROM IndexCursor INTO @TableName, @IndexName;

WHILE @@FETCH_STATUS = 0
BEGIN
    -- Ensure the index exists before attempting to drop it
    IF EXISTS (SELECT 1 FROM sys.indexes WHERE name = @IndexName AND object_id = OBJECT_ID(@SchemaName + '.' + @TableName))
    BEGIN
        -- Drop the index
        SET @DropIndexSQL = 'DROP INDEX ' + QUOTENAME(@IndexName) + ' ON ' + QUOTENAME(@SchemaName) + '.' + QUOTENAME(@TableName);
        EXEC sp_executesql @DropIndexSQL;
        PRINT 'Dropped index ' + @IndexName + ' on table ' + @TableName;
    END
    ELSE
    BEGIN
        PRINT 'Index ' + @IndexName + ' does not exist on table ' + @TableName;
    END

    FETCH NEXT FROM IndexCursor INTO @TableName, @IndexName;
END

CLOSE IndexCursor;
DEALLOCATE IndexCursor;

-- Summary of indexes removed
PRINT 'Summary of indexes removed:';
SELECT DISTINCT TableName, IndexName, IndexType FROM #IndexesToRemove;

-- Summary of constraints removed
PRINT 'Summary of constraints removed:';
SELECT DISTINCT ConstraintTable AS TableName, ConstraintName FROM #IndexesToRemove WHERE ConstraintName IS NOT NULL;

-- Clean up
DROP TABLE #IndexesToRemove;
DROP TABLE #ConstraintsToRemove;
