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


/*
--GET SPID STATUS--
 SELECT
	sp.spid, sp.[status], sp.loginame,
	sp.hostname, sp.[program_name],
	sp.blocked, sp.open_tran,
	dbname=db_name(sp.[dbid]), sp.cmd,
	sp.waittype, sp.waittime, sp.last_batch, st.[text]
FROM master.dbo.sysprocesses sp
	CROSS APPLY sys.dm_exec_sql_text (sp.[sql_handle]) st
WHERE spid = 459 -- Please specify the login which is output of first query
*/
