
--Add to db_datareader
EXEC master..sp_MSForeachdb 

'USE [?]

IF ''?''  not in (''master'', ''msdb'', ''model'', ''tempdb'')

BEGIN

 SELECT ''?'' 


IF  EXISTS (SELECT * FROM sys.database_principals WHERE name = ''US\msears'')
begin
 EXEC sp_addrolemember N''db_datareader'', N''US\msears''
 EXEC sp_addrolemember N''db_datawriter'', N''US\msears''
 --EXEC sp_addrolemember N''db_ddladmin'', N''HSFTS\US Production Access Group''
 end
ELSE
begin
 CREATE USER [HSFTS\US Production Access Group] FOR LOGIN [US\msears] 
 EXEC sp_addrolemember N''db_datareader'', N''US\msears''
 EXEC sp_addrolemember N''db_datawriter'', N''US\msears''
 --EXEC sp_addrolemember N''db_ddladmin'', N''HSFTS\US Production Access Group''
 end
END'
