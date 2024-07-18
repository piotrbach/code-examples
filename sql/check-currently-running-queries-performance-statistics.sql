/*
    Description: This script retrieves information about currently running queries
                 in SQL Server, including key performance statistics such as execution
                 time, CPU time, logical reads, and more. It allows parameterization
                 for checking queries within a specified time range and filtering by
                 performance metrics.
*/

-- Parameter Declaration
DECLARE @StartTime DATETIME = DATEADD(DAY, -7, GETDATE());  -- Start time for the query range
DECLARE @EndTime DATETIME = GETDATE();                      -- End time for the query range
DECLARE @MinElapsedTime DECIMAL(10, 2) = 0;                 -- Minimum elapsed time in seconds to filter
DECLARE @MaxCPUTime DECIMAL(10, 2) = 1000;                  -- Maximum CPU time in seconds to filter

-- Query to check currently running queries with performance statistics
SELECT
    -- Session ID
    r.session_id,
    -- Text of the query currently being executed
    SUBSTRING(st.text, 
              (r.statement_start_offset / 2) + 1, 
              ((CASE 
                  WHEN r.statement_end_offset = -1 THEN LEN(CONVERT(NVARCHAR(MAX), st.text)) * 2 
                  ELSE r.statement_end_offset 
               END - r.statement_start_offset) / 2) + 1) AS QueryText,
    -- Execution start time
    r.start_time,
    -- Elapsed time in seconds
    CAST((DATEDIFF(ms, r.start_time, GETDATE()) / 1000.0) AS DECIMAL(10, 2)) AS ElapsedTimeSeconds,
    -- CPU time in seconds
    CAST((r.cpu_time / 1000.0) AS DECIMAL(10, 2)) AS CPUTimeSeconds,
    -- Logical reads
    r.logical_reads,
    -- Writes
    r.writes,
    -- Physical reads
    r.reads,
    -- Blocking session ID (if any)
    r.blocking_session_id,
    -- Application name
    s.program_name,
    -- Host name
    s.host_name,
    -- Login name
    s.login_name,
    -- Database name
    DB_NAME(r.database_id) AS DatabaseName
FROM
    sys.dm_exec_requests AS r
    -- Join to retrieve the full text of the query
    CROSS APPLY sys.dm_exec_sql_text(r.sql_handle) AS st
    -- Join to retrieve session information
    JOIN sys.dm_exec_sessions AS s ON r.session_id = s.session_id
WHERE
    r.start_time BETWEEN @StartTime AND @EndTime
    AND CAST((DATEDIFF(ms, r.start_time, GETDATE()) / 1000.0) AS DECIMAL(10, 2)) >= @MinElapsedTime
    AND CAST((r.cpu_time / 1000.0) AS DECIMAL(10, 2)) <= @MaxCPUTime
ORDER BY
    ElapsedTimeSeconds DESC;

-- Notes:
-- 1. The `sys.dm_exec_requests` DMV provides information about each request that is executing within SQL Server.
-- 2. The `sys.dm_exec_sql_text` function retrieves the text of the SQL batch for a specified SQL handle.
-- 3. The `sys.dm_exec_sessions` DMV provides information about the active user connections in SQL Server.
-- 4. Execution time, CPU time, and logical reads are useful metrics for understanding query performance.
-- 5. Blocking session ID helps identify queries that might be causing performance issues by blocking other queries.
-- 6. Additional context like application name, host name, and login name can help identify the source of the queries.
