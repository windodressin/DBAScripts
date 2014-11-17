/*
--GET ROOT BLOCKER--
SELECT DISTINCT(l.request_SESSION_Id)
FROM sys.dm_tran_locks AS l
	 JOIN sys.dm_tran_locks AS l1 ON l.resource_associated_entity_id = l1.resource_associated_entity_id
WHERE l.request_status <> l1.request_status AND ( l.resource_description = l1.resource_description
	  OR (l.resource_description IS NULL AND l1.resource_description IS NULL))
	  AND (l.request_status)='GRANT' AND l.request_SESSION_Id 
	  NOT IN (SELECT DISTINCT(l.request_SESSION_Id)
			 FROM sys.dm_tran_locks AS l JOIN sys.dm_tran_locks AS l1 
			 ON l.resource_associated_entity_id = l1.resource_associated_entity_id
			 WHERE l.request_status <> l1.request_status 
			       AND ( l.resource_description = l1.resource_description
				   OR (l.resource_description IS NULL AND l1.resource_description IS NULL))
				   AND (l.request_status)='WAIT')
			 ORDER BY (l.request_SESSION_Id)
*/
----------------------------------------------------------------------------------------------

--Get current WAITS!!
SELECT 
	owt.session_id,
	owt.exec_context_id,
	owt.wait_duration_ms,
	owt.wait_type,
	wtd.Wait_Type_desc,
	owt.blocking_session_id,
	owt.resource_description,
	es.program_name,
	est.text,
	est.dbid,
	eqp.query_plan,

	es.cpu_time,
	es.memory_usage
FROM sys.dm_os_waiting_tasks owt
 JOIN sys.dm_exec_sessions es ON
	owt.session_id = es.session_id
INNER JOIN sys.dm_exec_requests er ON
	es.session_id = er.session_id 
--Added the join to wait_Type_description-- 
JOIN DBA_STORE..wait_Type_description wtd ON 
	owt.wait_type = wtd.wait_type
OUTER APPLY sys.dm_exec_sql_text (er.sql_handle) est
OUTER APPLY sys.dm_exec_query_plan (er.plan_handle) eqp
--WHERE es.is_user_process = 1
--and owt.session_id = 19
--and est.dbid = 15
where owt.session_id = 1260
ORDER BY owt.session_id, owt.exec_context_id

GO
--select * from  sys.dm_os_waiting_tasks where session_id = 1260
/*--------------------------------------------------------------------------------------*/

--What is Going On --from View WhatIsGoingOn
SELECT
OBJECT_NAME(objectid) as ObjectName
,SUBSTRING(stateText.text, (statement_start_offset/2)+1,
((CASE statement_end_offset
WHEN -1 THEN DATALENGTH(stateText.text)
ELSE statement_end_offset
END - statement_start_offset)/2) + 1) AS statement_text
,DB_Name(req.database_id) as DatabaseName

,req.cpu_time AS CPU_Time
,DATEDIFF(minute, last_request_start_time, getdate()) AS RunningMinutes
,req.Percent_Complete
,sess.HOST_NAME as RunningFrom
,LEFT(CLIENT_INTERFACE_NAME, 25) AS RunningBy
,sess.session_id AS SessionID
,req.blocking_session_id AS BlockingWith
,req.reads
,req.writes
,sess.[program_name]
,sess.login_name
,sess.status
,sess.last_request_start_time
,req.logical_reads
FROM
sys.dm_exec_requests req
INNER JOIN sys.dm_exec_sessions sess ON sess.session_id = req.session_id
AND sess.is_user_process = 1
CROSS APPLY
sys.dm_exec_sql_text(sql_handle) AS stateText
--where sess.session_id = 19
GO
-------------------------------------------------------------------------------------------------------


--MUST HAVE sp_WhoIsActive FROM ADAM MECHANIC INSTALLED
DBA_STORE..sp_WhoIsActive @get_plans =1, @get_additional_info =1  --1


-----------------------------------------------
/*
/*
--GET ROOT BLOCKER--
SELECT DISTINCT(l.request_SESSION_Id)
FROM sys.dm_tran_locks AS l
	 JOIN sys.dm_tran_locks AS l1 ON l.resource_associated_entity_id = l1.resource_associated_entity_id
WHERE l.request_status <> l1.request_status AND ( l.resource_description = l1.resource_description
	  OR (l.resource_description IS NULL AND l1.resource_description IS NULL))
	  AND (l.request_status)='GRANT' AND l.request_SESSION_Id 
	  NOT IN (SELECT DISTINCT(l.request_SESSION_Id)
			 FROM sys.dm_tran_locks AS l JOIN sys.dm_tran_locks AS l1 
			 ON l.resource_associated_entity_id = l1.resource_associated_entity_id
			 WHERE l.request_status <> l1.request_status 
			       AND ( l.resource_description = l1.resource_description
				   OR (l.resource_description IS NULL AND l1.resource_description IS NULL))
				   AND (l.request_status)='WAIT')
			 ORDER BY (l.request_SESSION_Id)

*/
*/