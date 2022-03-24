DECLARE @DatabaseName NVARCHAR(MAX) = '[database]'
DECLARE @CurrentSchemaName NVARCHAR(MAX)
DECLARE @CurrentIndexName NVARCHAR(MAX)
DECLARE @CurrentTableName NVARCHAR(MAX)
DECLARE @CmdRebuidIndex NVARCHAR(MAX)

DECLARE @tempIndexTable TABLE
(
    RowID                       int not null primary key identity(1,1),   
    IndexName                   NVARCHAR(MAX),
    IndexType                   NVARCHAR(MAX),
    TableName                   NVARCHAR(MAX),
    SchemaName                  NVARCHAR(MAX),
    AvgFragmentationInPercent   FLOAT,
    ObjectTypeDescription       NVARCHAR(MAX)     
)

INSERT INTO @tempIndexTable (IndexName, IndexType, TableName, SchemaName, AvgFragmentationInPercent, ObjectTypeDescription) (
    SELECT
        i.[name],
        s.[index_type_desc], --s.[index_type_desc]
        o.[name],
        sch.name,
        s.[avg_fragmentation_in_percent],
        o.type_desc
    FROM
        sys.dm_db_index_physical_stats (DB_ID(@DatabaseName), NULL, NULL, NULL, NULL)   AS  s   INNER JOIN
        sys.indexes                                                                     AS  i   ON  s.object_id = i.object_id
                                                                                                    AND s.index_id = i.index_id INNER JOIN
        sys.objects                                                                     AS  o   ON  i.object_id = o.object_id   INNER JOIN
        sys.schemas                                                                     AS  sch ON  sch.schema_id = o.schema_id
    WHERE (s.avg_fragmentation_in_percent > 30 and (i.[Name] like '%IX%' OR i.[Name] like '%PK%'))  
)

PRINT 'Indexes to rebuild:'
SELECT * FROM @tempIndexTable;

RETURN; -- remove this line if you want to run the command

DECLARE @totalCount INTEGER
SELECT @totalCount = count(1) FROM @tempIndexTable
DECLARE @counter INTEGER = 1

WHILE(@counter <= @totalCount)
BEGIN   

    SET @CurrentIndexName = (SELECT top 1 IndexName FROM @tempIndexTable WHERE RowID = @counter);
    SET @CurrentTableName = (SELECT top 1 TableName FROM @tempIndexTable WHERE RowID = @counter);
    SET @CurrentSchemaName = (SELECT top 1 SchemaName FROM @tempIndexTable WHERE RowID = @counter);
    
    PRINT 'Rebuild starting (' + convert(VARCHAR(5), @counter) + '/' + convert(VARCHAR(5), @totalCount) + ') [' + @CurrentIndexName + 
    '] ON [' + @CurrentSchemaName + '].[' + @CurrentTableName + '] at ' 
    + convert(varchar, getdate(), 121)

    BEGIN TRY
        SET @CmdRebuidIndex = 'ALTER INDEX [' + @CurrentIndexName + '] ON [' + @CurrentSchemaName + '].[' + @CurrentTableName + '] REBUILD PARTITION = ALL WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, ONLINE = ON, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON)'
            EXEC (@CmdRebuidIndex)
            PRINT 'Rebuild executed [' + @CurrentIndexName + '] ON [' + @CurrentSchemaName + '].[' + @CurrentTableName + '] at ' + convert(varchar, getdate(), 121)
    END TRY
    BEGIN CATCH
        PRINT 'Failed to rebuild [' + @CurrentIndexName + '] ON [' + @CurrentSchemaName + '].[' + @CurrentTableName + ']'
        PRINT ERROR_MESSAGE()
    END CATCH

    SET @counter += 1;
END
