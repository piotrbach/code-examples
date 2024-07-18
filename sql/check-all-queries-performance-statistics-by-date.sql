/*
    Description: This script retrieves information about all queries executed within
                 a specified date range in SQL Server, including key performance statistics
                 such as execution time, CPU time, logical reads, and more. It allows
                 parameterization for checking queries within a specified time range and
                 filtering by performance metrics.
                 
    Usage Instructions:
    - This script uses dynamic parameters to define the time range and performance filters.
    - To use fixed dates, simply set the values of @StartTime and @EndTime to the desired date and time.
    - Example: To set a fixed date range from '2024-07-18 09:07:19.893' to '2024-07-18 10:07:19.893',
      uncomment the fixed date declarations and comment out the relative date declarations.

    Notes:
    1. The `sys.dm_exec_query_stats` DMV provides aggregate performance statistics for cached query plans.
    2. The `sys.dm_exec_sql_text` function retrieves the text of the SQL batch for a specified SQL handle.
    3. Execution time, CPU time, and logical reads are useful metrics for understanding query performance.
    4. The script orders results by elapsed time in descending order, showing the longest-running queries first.
*/

-- Parameter Declaration

-- Use relative dates (last 7 days)
DECLARE @StartTime DATETIME = DATEADD(DAY, -7, GETDATE());  -- Start time for the query range
DECLARE @EndTime DATETIME = GETDATE();                      -- End time for the query range

-- Use fixed dates (uncomment to use)
-- DECLARE @StartTime DATETIME = '2024-07-18 09:07:19.893';  -- Fixed start time for the query range
-- DECLARE @EndTime DATETIME = '2024-07-18 10:07:19.893';    -- Fixed end time for the query range

DECLARE @MinElapsedTime DECIMAL(10, 2) = 0;                 -- Minimum elapsed time in seconds to filter
DECLARE @MaxCPUTime DECIMAL(10, 2) = 1000;                  -- Maximum CPU time in seconds to filter

-- Query to check all queries executed within the specified date range with performance statistics
SELECT
    -- Query execution statistics
    qs.creation_time AS QueryStartTime,
    qs.execution_count,
    qs.total_worker_time / 1000.0 AS TotalCPUTimeSeconds,
    qs.total_elapsed_time / 1000.0 AS TotalElapsedTimeSeconds,
    qs.total_logical_reads,
    qs.total_logical_writes,

    -- Text of the query being executed
    SUBSTRING(st.text, 
              (qs.statement_start_offset / 2) + 1, 
              ((CASE 
                  WHEN qs.statement_end_offset = -1 THEN LEN(CONVERT(NVARCHAR(MAX), st.text)) * 2 
                  ELSE qs.statement_end_offset 
               END - qs.statement_start_offset) / 2) + 1) AS QueryText,

    -- Execution start time
    qs.creation_time,
    -- Elapsed time in seconds
    CAST((DATEDIFF(ms, qs.creation_time, GETDATE()) / 1000.0) AS DECIMAL(10, 2)) AS ElapsedTimeSeconds,

    -- CPU time in seconds
    CAST((qs.total_worker_time / 1000.0) AS DECIMAL(10, 2)) AS CPUTimeSeconds,

    -- Logical reads
    qs.total_logical_reads,

    -- Writes
    qs.total_logical_writes,

    -- Database name
    DB_NAME(st.dbid) AS DatabaseName
FROM
    sys.dm_exec_query_stats AS qs
    -- Join to retrieve the full text of the query
    CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) AS st
WHERE
    qs.creation_time BETWEEN @StartTime AND @EndTime
    AND CAST((qs.total_elapsed_time / 1000.0) AS DECIMAL(10, 2)) >= @MinElapsedTime
    AND CAST((qs.total_worker_time / 1000.0) AS DECIMAL(10, 2)) <= @MaxCPUTime
ORDER BY
    ElapsedTimeSeconds DESC;

-- Notes:
-- 1. The `sys.dm_exec_query_stats` DMV provides aggregate performance statistics for cached query plans.
-- 2. The `sys.dm_exec_sql_text` function retrieves the text of the SQL batch for a specified SQL handle.
-- 3. Execution time, CPU time, and logical reads are useful metrics for understanding query performance.
-- 4. The script orders results by elapsed time in descending order, showing the longest-running queries first.
