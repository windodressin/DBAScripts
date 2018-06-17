--Get current sessions with command 
SELECT 
	es.session_id,
	es.host_name,
	es.login_name,
	es.status,
	db_name(es.database_id) as database_name,
	es.program_name,
	est.text,
	eqp.query_plan
FROM sys.dm_exec_sessions es 
INNER JOIN sys.dm_exec_requests er ON es.session_id = er.session_id
OUTER APPLY sys.dm_exec_sql_text (er.sql_handle) est
OUTER APPLY sys.dm_exec_query_plan (er.plan_handle) eqp
WHERE es.is_user_process = 1
ORDER BY es.session_id
GO

