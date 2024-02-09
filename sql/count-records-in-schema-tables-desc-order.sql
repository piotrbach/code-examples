/*
This script counts the number of records in each table within a specified schema 
of a MSSQL database and sorts the results in descending order by the record count.
You can set the schema name by modifying the @SchemaName variable.
*/

DECLARE @SchemaName NVARCHAR(255) = 'dbo'; -- Set the schema name here
DECLARE @CurrentTableName NVARCHAR(255); -- The name of the current table being processed
DECLARE @DynamicSQL NVARCHAR(MAX);       -- Dynamic SQL command to be constructed and executed
DECLARE @ResultsTable TABLE (TableName NVARCHAR(255), RecordCount INT); -- Table to store results

-- Cursor to iterate through all tables in the specified schema
DECLARE TableCursor CURSOR FOR 
    SELECT TABLE_NAME 
    FROM INFORMATION_SCHEMA.TABLES 
    WHERE TABLE_TYPE = 'BASE TABLE' AND TABLE_SCHEMA = @SchemaName;

OPEN TableCursor;

FETCH NEXT FROM TableCursor INTO @CurrentTableName;

WHILE @@FETCH_STATUS = 0
BEGIN
    -- Construct the SQL query to count records in the current table
    SET @DynamicSQL = 'SELECT ''' + @CurrentTableName + ''' AS TableName, COUNT(*) AS RecordCount FROM [' + @SchemaName + '].[' + @CurrentTableName + ']';
 
    -- Insert the result into the @ResultsTable
    INSERT INTO @ResultsTable (TableName, RecordCount)
    EXEC sp_executesql @DynamicSQL;

    FETCH NEXT FROM TableCursor INTO @CurrentTableName;
END

CLOSE TableCursor;
DEALLOCATE TableCursor;

-- Select final results, sorted by RecordCount in descending order
SELECT * FROM @ResultsTable ORDER BY RecordCount DESC;
