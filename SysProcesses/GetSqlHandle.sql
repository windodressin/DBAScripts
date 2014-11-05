DECLARE @handle varbinary(64)
--set @handle = 0x03000200a734c05067acb600229b00000100000000000000
SELECT @handle = sql_handle FROM MASTER..sysprocesses WHERE spid = 2529
SELECT text FROM sys.dm_exec_sql_text(@handle)
