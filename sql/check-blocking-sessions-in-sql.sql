-- This script checks for blocking sessions in SQL Server.
-- Blocking occurs when one session holds a lock on a resource 
-- and another session attempts to acquire a conflicting lock on the same resource.

-- Select relevant columns from the sys.dm_exec_requests view
SELECT 
    session_id,              -- The session ID of the request.
    wait_type,               -- The type of wait the request is experiencing.
    blocking_session_id,     -- The session ID of the session blocking this request.
    wait_time,               -- The total time the request has been waiting (in milliseconds).
    wait_resource            -- The resource on which the request is waiting.
FROM sys.dm_exec_requests
-- Filter the results to only include requests that are being blocked by another session.
WHERE blocking_session_id <> 0;
