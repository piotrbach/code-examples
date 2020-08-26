use [dbName]

/* Removing data from large table in MSSQL using batch */

CREATE TABLE [Logs] (
    [LogId] INTEGER NOT NULL IDENTITY(1, 1), 
    [Text] VARCHAR(MAX) NULL,
    [Severity] VARCHAR(7) NULL,
    [Created] DATETIME,
    PRIMARY KEY ([LogId])
);
GO

INSERT INTO [Logs]([Text],[Severity],[Created]) VALUES('Lorem ipsum 1','Error',GETDATE())
INSERT INTO [Logs]([Text],[Severity],[Created]) VALUES('Lorem ipsum 2','Warning',GETDATE())
INSERT INTO [Logs]([Text],[Severity],[Created]) VALUES('Lorem ipsum 3','Info',GETDATE())
INSERT INTO [Logs]([Text],[Severity],[Created]) VALUES('Lorem ipsum 4','Warning',GETDATE())
INSERT INTO [Logs]([Text],[Severity],[Created]) VALUES('Lorem ipsum 5','Warning',GETDATE())
INSERT INTO [Logs]([Text],[Severity],[Created]) VALUES('Lorem ipsum 6','Error',GETDATE())
INSERT INTO [Logs]([Text],[Severity],[Created]) VALUES('Lorem ipsum 7','Warning',GETDATE())
INSERT INTO [Logs]([Text],[Severity],[Created]) VALUES('Lorem ipsum 8','Warning',GETDATE())
INSERT INTO [Logs]([Text],[Severity],[Created]) VALUES('Lorem ipsum 9','Info',GETDATE())
INSERT INTO [Logs]([Text],[Severity],[Created]) VALUES('Lorem ipsum 10','Info',GETDATE())

SELECT count(1) FROM dbo.Logs;

DECLARE @tempLogIdWithPageIndexTable TABLE
(
	LogId INT,
	PageIndex INT
)

DECLARE @pageSize INTEGER = 2;
DECLARE @totalCount INTEGER
​
INSERT INTO @tempLogIdWithPageIndexTable (LogId, PageIndex) (
	SELECT  LogId, 
	CEILING(CAST(ROW_NUMBER() OVER(ORDER BY LogId) AS DECIMAL)/CAST(@pageSize AS DECIMAL)) AS PageIndex
	FROM [Logs] -- You can add WHERE conditions here
)

-- Get total counts of records to remove

SELECT @totalCount = count(1) FROM @tempLogIdWithPageIndexTable
​
DECLARE @pageCount INTEGER
SET @pageCount = CEILING(CAST(@totalCount as DECIMAL) / CAST(@pageSize as DECIMAL))
​
DECLARE @pageIndex INTEGER = 1
​
-- print the report with metrics before start

PRINT 'Total number of records to remove : ' + CAST(@totalCount as VARCHAR(MAX))
PRINT 'Page size : ' + CAST(@pageSize as VARCHAR(MAX))
PRINT 'Total pages : ' + CAST(@pageCount as VARCHAR(MAX))
PRINT 'Script started at : ' + CONVERT(varchar(25), getdate(), 120) 

-- delete records in a loop by paging

WHILE(@pageIndex <= @pageCount)
BEGIN	
	-- you can delete related entries first using JOIN here
	DELETE [dbo].Logs where LogId in 
	(SELECT LogId FROM @tempLogIdWithPageIndexTable WHERE PageIndex = @pageIndex)
​
	PRINT 'Processed page ' + CAST(@pageIndex as VARCHAR(MAX)) + '/' + CAST(@pageCount as VARCHAR(MAX))
	SET @pageIndex = @pageIndex + 1
END

PRINT 'Script finished at : ' + CONVERT(varchar(25), getdate(), 120) 

SET @totalCount = (SELECT count(1) FROM dbo.Logs)

-- print the report when the job is done
PRINT 'Number of records after deletion : ' + CAST(@totalCount as VARCHAR(MAX))

SELECT count(1) FROM dbo.Logs;