sp_msforeachdb '
USE [?]

IF ''?''  NOT IN (''master'', ''msdb'', ''model'')
BEGIN
SELECT [name], ([size]*8/1024) as ''Size in MB'' FROM sys.database_files
END
'