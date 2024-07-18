-- Variables to specify the database name, schema name, and index type
DECLARE @DatabaseName NVARCHAR(128) = '';  -- Replace with your database name
DECLARE @SchemaName NVARCHAR(128) = 'dbo'; -- Default schema is 'dbo'
DECLARE @IndexType NVARCHAR(128) = 'NONCLUSTERED';  -- Index type can be 'NONCLUSTERED', 'CLUSTERED', or 'ALL'

-- Temporary table to store index information
CREATE TABLE #IndexesToRemove (
    TableName NVARCHAR(128),
    IndexName NVARCHAR(128),
    IndexType NVARCHAR(128),
    CanDrop BIT
)

-- Dynamic SQL to populate the temporary table based on the specified criteria
DECLARE @SQL NVARCHAR(MAX) = '
USE ' + QUOTENAME(@DatabaseName) + ';
INSERT INTO #IndexesToRemove (TableName, IndexName, IndexType, CanDrop)
SELECT 
    t.name AS TableName,
    i.name AS IndexName,
    i.type_desc AS IndexType,
    CASE 
        WHEN fk.referenced_object_id IS NULL THEN 1 
        ELSE 0 
    END AS CanDrop
FROM 
    sys.indexes i
    JOIN sys.tables t ON i.object_id = t.object_id
    JOIN sys.schemas s ON t.schema_id = s.schema_id
    LEFT JOIN sys.foreign_keys fk ON i.object_id = fk.referenced_object_id
WHERE 
    s.name = @SchemaName AND
    (
        @IndexType = ''ALL'' OR
        (i.type = 1 AND @IndexType = ''CLUSTERED'') OR
        (i.type = 2 AND @IndexType = ''NONCLUSTERED'')
    )
'

-- Execute the dynamic SQL
EXEC sp_executesql @SQL, N'@SchemaName NVARCHAR(128), @IndexType NVARCHAR(128)', @SchemaName, @IndexType

-- Cursor to iterate over the indexes to be removed
DECLARE @TableName NVARCHAR(128)
DECLARE @IndexName NVARCHAR(128)
DECLARE @CanDrop BIT
DECLARE @DropSQL NVARCHAR(MAX)

DECLARE IndexCursor CURSOR FOR
SELECT TableName, IndexName, CanDrop FROM #IndexesToRemove

OPEN IndexCursor
FETCH NEXT FROM IndexCursor INTO @TableName, @IndexName, @CanDrop

WHILE @@FETCH_STATUS = 0
BEGIN
    IF @CanDrop = 1
    BEGIN
        SET @DropSQL = 'DROP INDEX ' + QUOTENAME(@IndexName) + ' ON ' + QUOTENAME(@SchemaName) + '.' + QUOTENAME(@TableName)
        EXEC sp_executesql @DropSQL
        PRINT 'Dropped index ' + @IndexName + ' on table ' + @TableName
    END
    ELSE
    BEGIN
        PRINT 'Cannot drop index ' + @IndexName + ' on table ' + @TableName + ' because it is being used for FOREIGN KEY constraint enforcement.'
    END

    FETCH NEXT FROM IndexCursor INTO @TableName, @IndexName, @CanDrop
END

CLOSE IndexCursor
DEALLOCATE IndexCursor

-- Summary of indexes removed
PRINT 'Summary of indexes removed:'
SELECT TableName, IndexName, IndexType FROM #IndexesToRemove WHERE CanDrop = 1

-- Summary of indexes not removed
PRINT 'Summary of indexes not removed:'
SELECT TableName, IndexName, IndexType FROM #IndexesToRemove WHERE CanDrop = 0

-- Clean up
DROP TABLE #IndexesToRemove
