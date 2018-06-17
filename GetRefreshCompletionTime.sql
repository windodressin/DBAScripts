

select percent_complete, * from sys.dm_exec_requests where command like '%restore%'