set nocount on

:setvar dbname1 "AllegroIntegration_REC"
:setvar dbname2 "Allegro_REC"

:setvar srcdbname1 "AllegroIntegration_Prod"
:setvar srcdbname2 "Allegro_Prod"
:setvar credname "SQLAzureStorage"

/**Check if app pool exists and comment in or out **/

--REM print 'Stopping web app pools for $(dbname2) ' + '. Start Time: ' + cast(current_timestamp as varchar(30))
--REM use $(dbname2)
--REM exec cpndbadb.dbo.xp_execresultset 'select ''print ''''Attempting to stop app pool on server: '' + server + '' ''''; exec xp_cmdshell ''''%SystemRoot%\system32\WindowsPowerShell\v1.0\powershell.exe -Command Invoke-Command -ComputerName '' + server + '' -ScriptBlock { if ( (get-WebAppPoolState \"'' + right(url, charindex(''/'', reverse(url))-1) + ''\").Value -eq \"Started\" ) { Stop-WebAppPool -Name \"'' + right(url, charindex(''/'', reverse(url))-1) + ''\";} Start-Sleep -s 7; (get-WebAppPoolState \"'' + right(url, charindex(''/'', reverse(url))-1) + ''\").Value; }''''''
-- from gridserver', '$(dbname2)'
--go


print 'Starting restore of AllegroIntegration_Prod production DB as $(dbname1) to SQL instance ' + cast(@@servername as varchar(128)) + '. Start Time: ' + cast(current_timestamp as varchar(30))
use master
go
while exists (select 1 from sys.databases where name = '$(dbname1)') and 
(databasepropertyex('$(dbname1)', 'UserAccess') <> 'RESTRICTED_USER') and 
(databasepropertyex('$(dbname1)', 'Updateability') <> 'READ_ONLY') 
begin
   exec cpnDBAdb.dbo.xp_execresultset 'select ''kill '' + ltrim(rtrim(str(spid))) from sysprocesses where dbid = db_id(''$(dbname1)'') and hostname <> '''' ', master
   if exists (select 1 from sys.databases where name = '$(dbname1)')
      alter database $(dbname1) set restricted_user with rollback immediate;
   exec cpnDBAdb.dbo.xp_execresultset 'select ''kill '' + ltrim(rtrim(str(spid))) from sysprocesses where dbid = db_id(''$(dbname1)'') and hostname <> '''' ', master
end
go


declare @URL varchar(512), @filePath varchar(512)
set @URL = 'https://cpnsqlbackupprd01.blob.core.windows.net/pzpwalgdb01-mssqlserver/$(srcdbname1)_' + convert(varchar(30), getdate()-1, 112) + '.bak'
set @filePath = 'K:\BACKUP\DownloadedFromAzure\AllegroIntegration_Prod_20180530.bak'

restore database $(dbname1)
from disk = @filePath
with stats, replace, 
--from URL = @URL
--with stats, replace, credential = '$(credname)', 
move 'PassBack' to 'J:\DBData\$(dbname1)\$(dbname1).mdf',
move 'PassBack_log' to 'G:\DBLog\$(dbname1)\$(dbname1)_log.ldf',
move 'PassBack_1' to 'J:\DBData\$(dbname1)\$(dbname1)_1.ndf'
go

alter database $(dbname1) set recovery simple
go
use $(dbname1)
go
dbcc shrinkfile (N'PassBack_log', 0, TRUNCATEONLY)
go


print 'Starting restore of Allegro_Prod production DB as $(dbname2) to SQL instance ' + cast(@@servername as varchar(128)) + '. Start Time: ' + cast(current_timestamp as varchar(30))
use master
go
while exists (select 1 from sys.databases where name = '$(dbname2)') and 
(databasepropertyex('$(dbname2)', 'UserAccess') <> 'RESTRICTED_USER') and 
(databasepropertyex('$(dbname2)', 'Updateability') <> 'READ_ONLY') 
begin
   exec cpnDBAdb.dbo.xp_execresultset 'select ''kill '' + ltrim(rtrim(str(spid))) from sysprocesses where dbid = db_id(''$(dbname2)'') and hostname <> '''' ', master
   if exists (select 1 from sys.databases where name = '$(dbname2)')
      alter database $(dbname2) set restricted_user with rollback immediate;
   exec cpnDBAdb.dbo.xp_execresultset 'select ''kill '' + ltrim(rtrim(str(spid))) from sysprocesses where dbid = db_id(''$(dbname2)'') and hostname <> '''' ', master
end
go

declare @URL varchar(512), @filePath varchar(512)
set @URL = 'https://cpnsqlbackupprd01.blob.core.windows.net/pzpwalgdb01-mssqlserver/$(srcdbname2)_' + convert(varchar(30), getdate()-1, 112) + '.bak'
set @filePath = 'K:\BACKUP\DownloadedFromAzure\Allegro_Prod_20180530.bak'

restore database $(dbname2) from 
disk = @filePath
with stats, replace, 
--URL = @URL
--with stats, replace, credential = '$(credname)', 
move 'allegro_gold' to 'J:\DBData\$(dbname2)\$(dbname2).mdf',
move 'allegro_gold_log' to 'G:\DBLog\$(dbname2)\$(dbname2)_log.ldf'
go

alter database $(dbname2) set recovery simple
go
use $(dbname2)
go
dbcc shrinkfile (N'allegro_gold_log', 0, TRUNCATEONLY)
go


print 'Run postrefresh for $(dbname1) and $(dbname2) on SQL instance ' + cast(@@servername as varchar(128)) + '. Start Time: ' + cast(current_timestamp as varchar(30))
use $(dbname2)
go
delete dbo.iceconfig
delete dbo.cpn_valuationgridserver
go
exec sp_execPostDBrefresh
go


print 'Completed restore of $(dbname1) and $(dbname2) DBs to SQL instance ' + cast(@@servername as varchar(128)) + '. End Time: ' + cast(current_timestamp as varchar(30))
go


use $(dbname2)
exec cpndbadb.dbo.xp_execresultset 'select ''print ''''Attempting to start app pool on server: '' + server + '' ''''; exec xp_cmdshell ''''%SystemRoot%\system32\WindowsPowerShell\v1.0\powershell.exe -Command Invoke-Command -ComputerName '' + server + '' -ScriptBlock { if ( (get-WebAppPoolState \"'' + right(url, charindex(''/'', reverse(url))-1) + ''\").Value -eq \"Stopped\" ) { Start-WebAppPool -Name \"'' + right(url, charindex(''/'', reverse(url))-1) + ''\";} Start-Sleep -s 7; (get-WebAppPoolState \"'' + right(url, charindex(''/'', reverse(url))-1) + ''\").Value; }''''''
from gridserver', '$(dbname2)'
go
print 'Started web app pools for $(dbname2) ' + '. Start Time: ' + cast(current_timestamp as varchar(30))
go


