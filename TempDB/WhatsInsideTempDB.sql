
SELECT 
    t1.session_id, 
    t1.request_id, 
    t1.task_alloc,
    t1.task_dealloc, 
    t2.sql_handle, 
    t2.statement_start_offset, 
    t2.statement_end_offset, 
    t2.plan_handle
FROM (Select session_id, request_id,
        SUM(internal_objects_alloc_page_count) AS task_alloc,
        SUM (internal_objects_dealloc_page_count) AS task_dealloc 
  FROM sys.dm_db_task_space_usage 
  GROUP BY session_id, request_id) AS t1, 
  sys.dm_exec_requests AS t2
WHERE t1.session_id = t2.session_id  AND 
        (t1.request_id = t2.request_id) and
        (t1.task_alloc + t1.task_dealloc > 0)
ORDER BY t1.task_alloc DESC