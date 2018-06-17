--Get completion time
select 
	percent_complete AS PercentComplete, 
	session_id, 
	Command, 
	DB_NAME(database_id), 
	dop, 
	blocking_session_id, 
	wait_type 
from sys.dm_exec_requests
where command like '%restore%' or command like '%backup%'



