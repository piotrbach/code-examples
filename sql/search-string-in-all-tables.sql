-- This script searches for a specific text in all text-based columns across the database.
-- Adjust the data types and search string as needed for your specific requirements.

DECLARE @TargetString VARCHAR(255) = 'Piotr Bach' -- The text string to search for
DECLARE @CurrentTableName NVARCHAR(255)  -- The name of the current table being processed
DECLARE @CurrentColumnName NVARCHAR(255) -- The name of the current column being processed
DECLARE @DynamicSQL NVARCHAR(MAX)        -- Dynamic SQL command to be constructed and executed

-- Cursor to iterate through all relevant tables and columns
DECLARE ColumnCursor CURSOR FOR 
    SELECT TABLE_NAME, COLUMN_NAME 
    FROM INFORMATION_SCHEMA.COLUMNS 
    WHERE DATA_TYPE IN ('varchar', 'char', 'text', 'nvarchar', 'ntext', 'varbinary') -- Include appropriate data types

OPEN ColumnCursor

FETCH NEXT FROM ColumnCursor INTO @CurrentTableName, @CurrentColumnName

WHILE @@FETCH_STATUS = 0
BEGIN
    -- Construct the SQL query for the current column
    SET @DynamicSQL = 'SELECT * FROM [' + @CurrentTableName + '] WHERE [' + @CurrentColumnName + '] LIKE ''%' + @TargetString + '%'''
    
    -- Print the dynamic SQL for debugging purposes
    PRINT('Executing search for "' + @TargetString + '" in table [' + @CurrentTableName + '], column [' + @CurrentColumnName + '].')

    -- Execute the dynamic SQL
    EXEC sp_executesql @DynamicSQL

    FETCH NEXT FROM ColumnCursor INTO @CurrentTableName, @CurrentColumnName
END

CLOSE ColumnCursor
DEALLOCATE ColumnCursor
