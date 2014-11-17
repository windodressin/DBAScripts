
USE DBA_STORE
GO

--Show Advanced option
sp_configure 'show advanced options', 60
 go
 reconfigure
 go
 sp_configure
 go
 
--  Now, set the blocked process threshold to 10 seconds
 sp_configure 'blocked process threshold', 60 -- SET AT 2 FOR TESTING
 go
 
 reconfigure WITH OVERRIDE
 go
 
 ALTER DATABASE [DBA_STORE]
 SET ENABLE_BROKER WITH NO_WAIT
  GO
 
  create table dbo.BlockedProcessesEventLog
(
	ID int not null identity(1,1),
	EventDate datetime not null,
	-- ID of the database where locking occurs
	DatabaseID smallint not null,
	-- Blocking resource
	[Resource] varchar(64) not null,
	-- Wait time in MS
	WaitTime int not null,
	-- Raw blocked process report
	BlockedProcessReport xml not null,
	-- SPID of the blocked process
	BlockedSPID smallint not null,
	-- XACTID of the blocked process
	BlockedXactId bigint null,
	-- Blocked Lock Request Mode
	BlockedLockMode varchar(16) null,
	-- Transaction isolation level for
	-- blocked session
	BlockedIsolationLevel varchar(32) null,
	-- Top SQL Handle from execution stack
	BlockedSQLHandle varbinary(64) null,
	-- Blocked SQL Statement Start offset
	BlockedStmtStart int null,
	-- Blocked SQL Statement End offset
	BlockedStmtEnd int null,
	-- Blocked SQL based on SQL Handle
	BlockedSql nvarchar(max) null,
	-- Blocked InputBuf from the report
	BlockedInputBuf nvarchar(max), 
	-- Blocked Plan based on SQL Handle
	BlockedQueryPlan xml null,
	-- SPID of the blocking process
	BlockingSPID smallint null,
	-- Blocking Process status
	BlockingStatus varchar(16) null,
	-- Blocking Process Transaction Count
	BlockingTranCount int not null, 
	-- Blocking InputBuf from the report
	BlockingInputBuf nvarchar(max) null,
	-- Blocked SQL based on SQL Handle
	BlockingSql nvarchar(max) null,
	-- Blocking Plan based on SQL Handle
	BlockingQueryPlan xml null,
	constraint PK_BlockedProcessesInfo
	primary key nonclustered(ID)
)
go

create unique clustered index 
IDX_BlockedProcessInfo_EventDate_ID
on dbo.BlockedProcessesEventLog(EventDate, ID)
go
  
  --CHECK IF QUEUE EXISTS
 IF NOT EXISTS (SELECT * FROM [sys].[service_queues] 
				WHERE name = N'BlockedProcessReportQueue')
 CREATE QUEUE [dbo].[BlockedProcessReportQueue]
 GO

  --CREATE SERVICE
  CREATE SERVICE [//CAR.com/BlockedProcessReportService] 
  AUTHORIZATION [dbo] ON QUEUE [dbo].[BlockedProcessReportQueue] 
  ([http://schemas.microsoft.com/SQL/Notifications/PostEventNotification])
 GO

--CREATE ROUTE
 CREATE ROUTE [BlockedProcessReportRoute]   
 AUTHORIZATION [dbo]   
 WITH SERVICE_NAME  = N'//CAR.com/BlockedProcessReportService' , ADDRESS  = N'LOCAL' 
 GO
 
 --CREATE EVENT
 EXECUTE AS LOGIN = 'sa';

 DECLARE @AuditServiceBrokerGuid [uniqueidentifier]
		,@SQL [varchar] (max);

 -- Retrieving the service broker guid of CaptureDeadlockGraph database
 SELECT @AuditServiceBrokerGuid = [service_broker_guid]
 FROM [master].[sys].[databases]
 WHERE [name] = 'DBA_STORE'
 
 -- Building and executing dynamic SQL to create event notification objects
 -- Dynamic SQL to create BlockedProcessReportEventNotification event notification object
 SET @SQL = 'IF EXISTS (SELECT * 
			 FROM [sys].[server_event_notifications] 
			 WHERE [name] = ''BlockedProcessReportEventNotification'')
 
 DROP EVENT NOTIFICATION BlockedProcessReportEventNotification ON SERVER 
 
 CREATE EVENT NOTIFICATION BlockedProcessReportEventNotification 
 ON SERVER
 WITH fan_in
 FOR BLOCKED_PROCESS_REPORT
 TO SERVICE ''//CAR.com/BlockedProcessReportService'', ''' 
 + CAST(@AuditServiceBrokerGuid AS [varchar](50)) + ''';'
 EXEC (@SQL)
 GO

 --CHECK ON EVENT 
 USE DBA_STORE
 GO
 SELECT * FROM [sys].[server_event_notifications]
 WHERE [name] = 'BlockedProcessReportEventNotification';
 GO

 --CREATE ACTIVATION PROC
 USE DBA_STORE
 go
create procedure [dbo].[usp_CaptureBlockingEvents]
with execute as owner
as
begin
	set nocount on
    
	declare
		@Msg varbinary(max)
		,@Ch uniqueidentifier
		,@MsgType sysname      
		,@Report xml
		,@EventDate datetime
		,@DBID smallint
		,@EventType varchar(128)
       
	while 1 = 1
	begin
		begin try
			begin tran
				-- for simplicity sake of that example
				-- we are processing data in one-by-one facion      
				-- rather than load everything to the temporary
				-- table variable
				waitfor 
				(
					receive top (1)
						@ch = conversation_handle
						,@Msg = message_body
						,@MsgType = message_type_name
					from dbo.BlockedProcessNotificationQueue
				), timeout 10000

				if @@ROWCOUNT = 0
				begin
					rollback
					break
				end          

				if @MsgType = N'http://schemas.microsoft.com/SQL/Notifications/EventNotification'
				begin
					select 
						@EventDate = convert(xml,@Msg).value('/EVENT_INSTANCE[1]/StartTime[1]','datetime')
						,@DBID = convert(xml,@Msg).value('/EVENT_INSTANCE[1]/DatabaseID[1]','smallint')
						,@EventType = convert(xml,@Msg).value('/EVENT_INSTANCE[1]/EventType[1]','varchar(128)')
						
					if @EventType = 'BLOCKED_PROCESS_REPORT'
					begin
						select                  
							@Report = convert(xml,@Msg).query('/EVENT_INSTANCE[1]/TextData[1]/*')

						merge into dbo.BlockedProcessesEventLog as Source
						using
						(
							select 
								repData.[Resource], repData.WaitTime
								,repData.BlockedSPID, repData.BlockedLockMode, repData.BlockedIsolationLevel
								,repData.BlockedSqlHandle, repData.BlockedStmtStart, repData.BlockedStmtEnd
								,repData.BlockedInputBuf, repData.BlockingSPID, repData.BlockingStatus
								,repData.BlockingTranCount, repData.BlockedXactID
								,SUBSTRING(
									BlockedSQLText.Text, 
									(repData.BlockedStmtStart / 2) + 1,
									((
										CASE repData.BlockedStmtEnd
											WHEN -1 
											THEN DATALENGTH(BlockedSQLText.text)
											ELSE repData.BlockedStmtEnd
										END - repData.BlockedStmtStart) / 2) + 1
								) as BlockedSQL
								,coalesce(blockedERPlan.query_plan,blockedQSPlan.query_plan) as BlockedQueryPlan
								,SUBSTRING(
									BlockingSQLText.Text, 
									(repData.BlockingStmtStart / 2) + 1,
									((
										CASE repData.BlockingStmtEnd
											WHEN -1 
											THEN DATALENGTH(BlockingSQLText.text)
											ELSE repData.BlockingStmtEnd
										END - repData.BlockingStmtStart) / 2) + 1
								) as BlockingSQL
								,repData.BlockingInputBuf
								,BlockingQSPlan.query_plan as BlockingQueryPlan	               
							from
								-- Parsing report XML
								(
									select 
										@Report.value('/blocked-process-report[1]/blocked-process[1]/process[1]/@waitresource','varchar(64)') as [Resource]
										,@Report.value('/blocked-process-report[1]/blocked-process[1]/process[1]/@xactid','bigint') as BlockedXactID
										,@Report.value('/blocked-process-report[1]/blocked-process[1]/process[1]/@waittime','int') as WaitTime
										,@Report.value('/blocked-process-report[1]/blocked-process[1]/process[1]/@spid','smallint') as BlockedSPID
										,@Report.value('/blocked-process-report[1]/blocked-process[1]/process[1]/@lockMode','varchar(16)') as BlockedLockMode
										,@Report.value('/blocked-process-report[1]/blocked-process[1]/process[1]/@isolationlevel','varchar(32)') as BlockedIsolationLevel
										,@Report.value('xs:hexBinary(substring((/blocked-process-report[1]/blocked-process[1]/process[1]/executionStack[1]/frame[1]/@sqlhandle)[1],3))','varbinary(max)') as BlockedSQLHandle
										,isnull(@Report.value('/blocked-process-report[1]/blocked-process[1]/process[1]/executionStack[1]/frame[1]/@stmtstart','int'), 0) as BlockedStmtStart
										,isnull(@Report.value('/blocked-process-report[1]/blocked-process[1]/process[1]/executionStack[1]/frame[1]/@stmtend','int'), -1) as BlockedStmtEnd
										,@Report.value('/blocked-process-report[1]/blocked-process[1]/process[1]/inputbuf[1]','nvarchar(max)') as BlockedInputBuf
										,@Report.value('/blocked-process-report[1]/blocking-process[1]/process[1]/@spid','smallint') as BlockingSPID
										,@Report.value('/blocked-process-report[1]/blocking-process[1]/process[1]/@status','varchar(16)') as BlockingStatus
										,@Report.value('/blocked-process-report[1]/blocking-process[1]/process[1]/@trancount','smallint') as BlockingTranCount
										,@Report.value('/blocked-process-report[1]/blocking-process[1]/process[1]/inputbuf[1]','nvarchar(max)') as BlockingInputBuf
										,@Report.value('xs:hexBinary(substring((/blocked-process-report[1]/blocking-process[1]/process[1]/executionStack[1]/frame[1]/@sqlhandle)[1],3))','varbinary(max)') as BlockingSQLHandle
										,isnull(@Report.value('/blocked-process-report[1]/blocking-process[1]/process[1]/executionStack[1]/frame[1]/@stmtstart','int'), 0) as BlockingStmtStart
										,isnull(@Report.value('/blocked-process-report[1]/blocking-process[1]/process[1]/executionStack[1]/frame[1]/@stmtend','int'), -1) as BlockingStmtEnd										
										
								) as repData 
								-- Getting Query Text					
								outer apply 
								(
									select
										case 
											when IsNull(repData.BlockedSQLHandle,0x) = 0x
											then null
											else 
												(
													select text 
													from sys.dm_exec_sql_text(repData.BlockedSQLHandle)
												)
										end as Text
								) BlockedSQLText
								outer apply 
								(
									select
										case 
											when IsNull(repData.BlockingSQLHandle,0x) = 0x
											then null
											else 
												(
													select text 
													from sys.dm_exec_sql_text(repData.BlockingSQLHandle)
												)
										end as Text
								) BlockingSQLText
								-- Check if statement is still blocked in sys.dm_exec_requests
								outer apply
								(
									select  qp.query_plan
									from 
										sys.dm_exec_requests er
											cross apply sys.dm_exec_query_plan(er.plan_handle) qp
									where 
										er.session_id = repData.BlockedSPID and 
										er.sql_handle = repData.BlockedSQLHandle and 
										er.statement_start_offset = repData.BlockedStmtStart and
										er.statement_end_offset = repData.BlockedStmtEnd
								) blockedERPlan
								-- if there is no plan handle let's try sys.dm_exec_query_stats
								outer apply
								(
									select
										case 
											when blockedERPlan.query_plan is null
											then
												(
													select top 1 qp.query_plan
													from
														sys.dm_exec_query_stats qs with (nolock) 
															cross apply sys.dm_exec_query_plan(qs.plan_handle) qp
													where	
														qs.sql_handle = repData.BlockedSQLHandle and 
														qs.statement_start_offset = repData.BlockedStmtStart and
														qs.statement_end_offset = repData.BlockedStmtEnd and
														@EventDate between qs.creation_time and qs.last_execution_time                         
													order by
														qs.last_execution_time desc
												) 
										end as query_plan
								) blockedQSPlan  		
								outer apply
								(
									select top 1 qp.query_plan
									from
										sys.dm_exec_query_stats qs with (nolock) 
											cross apply sys.dm_exec_query_plan(qs.plan_handle) qp
									where	
										qs.sql_handle = repData.BlockingSQLHandle and 
										qs.statement_start_offset = repData.BlockingStmtStart and
										qs.statement_end_offset = repData.BlockingStmtEnd 
									order by
										qs.last_execution_time desc
								) BlockingQSPlan  			               
						) as Target			
						on 
							Source.BlockedSPID = target.BlockedSPID and
							IsNull(Source.BlockedXactId,-1) = IsNull(target.BlockedXactId,-1) and              
							Source.[Resource] = target.[Resource] and              
							Source.BlockingSPID = target.BlockingSPID and
							Source.BlockedSQLHandle = target.BlockedSQLHandle and              
							Source.BlockedStmtStart = target.BlockedStmtStart and   
							Source.BlockedStmtEnd = target.BlockedStmtEnd and   
							Source.EventDate >= dateadd(millisecond,-target.WaitTime - 100, @EventDate)
						when matched then
							update set source.WaitTime = target.WaitTime
						when not matched then
							insert (EventDate,DatabaseID,[Resource],WaitTime,BlockedProcessReport,BlockedSPID
								,BlockedXactId,BlockedLockMode,BlockedIsolationLevel,BlockedSQLHandle,BlockedStmtStart
								,BlockedStmtEnd,BlockedSql,BlockedInputBuf,BlockedQueryPlan,BlockingSPID,BlockingStatus
								,BlockingTranCount,BlockingSql,BlockingInputBuf,BlockingQueryPlan)          
							values(@EventDate,@DBID,Target.[Resource],Target.WaitTime
								,@Report,Target.BlockedSPID,Target.BlockedXactId,Target.BlockedLockMode
								,Target.BlockedIsolationLevel,Target.BlockedSQLHandle,Target.BlockedStmtStart
								,Target.BlockedStmtEnd,Target.BlockedSql,Target.BlockedInputBuf,Target.BlockedQueryPlan
								,Target.BlockingSPID,Target.BlockingStatus,Target.BlockingTranCount
								,Target.BlockingSql,Target.BlockingInputBuf,Target.BlockingQueryPlan);

						-- Perhaps send email here?
					end -- @EventType = BLOCKED_PROCESS_REPORT
				end -- @MsgType = http://schemas.microsoft.com/SQL/Notifications/EventNotification
				else if @MsgType = N'http://schemas.microsoft.com/SQL/ServiceBroker/EndDialog'
					end conversation @ch
				-- else handle errors here
			commit
		end try
		begin catch
			-- capture info about error message here      
			if @@TRANCOUNT > 0
				rollback;      

			-- perhaps add some Email Notification here
			-- Do not forget about the fact that SP is running from Service Broker
			-- you need to either setup certificate based security or set TRUSTWORTHY ON
			-- in order to use DB Mail
			break
		end catch
	end
end
go    

 --ACTIVATE QUEUE
 ALTER QUEUE [dbo].[BlockedProcessReportQueue]
 WITH STATUS = ON
,ACTIVATION (PROCEDURE_NAME = [dbo].[usp_CaptureBlockingEvents]
,STATUS = ON
,MAX_QUEUE_READERS = 50
,EXECUTE AS OWNER)
 GO 
 
 --QUERY TABLE
 SELECT *
 FROM [dbo].[BlockedProcessesEventLog]
 GO
 
 --TURN ON/OFF SERVICE BROKER
 --ALTER DATABASE DBA_STORE SET ENABLE_BROKER WITH NO_WAIT
 --GO
 --ALTER DATABASE DBA_STORE SET DISABLE_BROKER WITH NO_WAIT

 --CHECK FOR BROKER QUEUE ERRORS
 XP_READERRORLOG 0,1, 'QUEUE'