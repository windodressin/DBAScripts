--Quick WhatsUp! 
SELECT 
	owt.session_id,
	owt.blocking_session_id,
	DB_NAME(est.dbid) AS database_name,
	owt.wait_type,
	wtd.wait_type_desc,
	est.text,
	owt.resource_description,
	es.program_name
	--eqp.query_plan	
FROM sys.dm_os_waiting_tasks owt
INNER JOIN sys.dm_exec_sessions es ON
	owt.session_id = es.session_id
INNER JOIN sys.dm_exec_requests er ON
	es.session_id = er.session_id 
--Added the join to wait_Type_description-- 
JOIN DBA_STORE..wait_Type_description wtd ON 
	owt.wait_type = wtd.wait_type
OUTER APPLY sys.dm_exec_sql_text (er.sql_handle) est
--OUTER APPLY sys.dm_exec_query_plan (er.plan_handle) eqp
WHERE es.is_user_process = 1
ORDER BY owt.session_id, owt.exec_context_id
GO


