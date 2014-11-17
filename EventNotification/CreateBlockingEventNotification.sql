
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
 
  CREATE TABLE [dbo].[BlockedProcessesEventLog] (
	 [EventID] [bigint] IDENTITY(1, 1) NOT NULL
	,[EventType] [nvarchar](128) NOT NULL
    ,[AlertTime] [datetime] NULL
    ,[Database] [nvarchar](256) NULL
    ,[BlockedProcessReport] [xml] NULL
    ,[BlockingEventData] [xml] NULL
    ,[AuditDate] [smalldatetime] DEFAULT CURRENT_TIMESTAMP NOT NULL
    ,CONSTRAINT [PK_SQLServerBlockingEvents_EventID] 
     PRIMARY KEY CLUSTERED ([EventID] ASC) 
     WITH (PAD_INDEX = OFF
     ,STATISTICS_NORECOMPUTE = OFF
     ,IGNORE_DUP_KEY = OFF
     ,ALLOW_ROW_LOCKS = ON
     ,ALLOW_PAGE_LOCKS = ON
	 ,FILLFACTOR = 100) ON [PRIMARY]) ON [PRIMARY]

 GO
  
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
 GO
 IF  EXISTS (SELECT * FROM [sys].[objects] 
 WHERE [object_id] = OBJECT_ID(N'[dbo].[usp_CaptureBlockingEvents]') 
 AND [type] = ('P'))
 
 DROP PROCEDURE [dbo].[usp_CaptureBlockingEvents]
 GO
 SET ANSI_NULLS ON
 GO
 SET QUOTED_IDENTIFIER ON
 GO

 CREATE PROC [dbo].[usp_CaptureBlockingEvents]
--Purpose:
--Service broker service program stored procedure that will be called by 
--BlockedProcessReportQueue, and will process messages from this queue.
AS 
BEGIN
  BEGIN TRY
  DECLARE 
  @EventTime [datetime]
 ,@EventType [varchar](128)
 ,@Database [nvarchar](256)
 ,@BlockedProcessReport [xml]
 ,@message_body [xml] 
 ,@message_type_name [nvarchar](256)
 ,@dialog [uniqueidentifier]
 
  WHILE (1 = 1)
	BEGIN
		BEGIN
			BEGIN TRANSACTION
			-- Receive the next available message from the queue
			WAITFOR (-- just handle one message at a time
			RECEIVE TOP(1)
			--the type of message received 
			 @message_type_name = [message_type_id]
			-- the message contents
			,@message_body = CAST([message_body] AS [xml])
			-- the identifier of the dialog this message was received on
			,@dialog = [conversation_handle] 
			-- if the queue is empty for one second, give UPDATE and go away
			FROM [dbo].[BlockedProcessReportQueue]), TIMEOUT 2000 
			--rollback and exit if no messages were found
			IF (@@ROWCOUNT = 0)
				BEGIN
					ROLLBACK TRANSACTION
					BREAK
				END
			--end conversation of end dialog message
		IF (@message_type_name = 'http://schemas.microsoft.com/SQL/ServiceBroker/EndDialog')
			BEGIN
				PRINT 'End Dialog received for dialog # ' + CAST(@dialog as [nvarchar](40));
				END CONVERSATION @dialog;
			END;
		ELSE
			BEGIN
				SET @EventTime = CAST(@message_body AS [xml]).value('(/EVENT_INSTANCE/PostTime)[1]', 'datetime')
				SET @Database = DB_NAME(CAST(@message_body AS [xml]).value('(/EVENT_INSTANCE/DatabaseID)[1]', 'int'))
				SET @EventType = CAST(@message_body.query('/EVENT_INSTANCE/EventType/text()') AS [nvarchar](128))
				SET @BlockedProcessReport = CAST(@message_body AS [xml]).query('(/EVENT_INSTANCE/TextData/blocked-process-report/.)[1]')
				INSERT INTO [dbo].[BlockedProcessesEventLog]
				([EventType]
				,[AlertTime]
				,[Database]
				,[BlockedProcessReport]
				,[BlockingEventData])
				VALUES 
				(@EventType, @EventTime, @Database, @BlockedProcessReport, @message_body)
			END
		END
			-- Commit the transaction. At any point before this, we could roll
			-- back - the received message would be back on the queue AND the response
			-- wouldn't be sent.
		--COMMIT TRANSACTION
	END --end of loop
  END TRY  
  BEGIN CATCH 
	DECLARE @ErrorMessage [nvarchar](4000);
    DECLARE @ErrorSeverity [int];
    DECLARE @ErrorState [int];
    SELECT 
         @ErrorMessage = ERROR_MESSAGE(),
         @ErrorSeverity = ERROR_SEVERITY(),
         @ErrorState = ERROR_STATE();
		-- Use RAISERROR inside the CATCH block to return error
		-- information about the original error that caused
		-- execution to jump to the CATCH block.
    RAISERROR (@ErrorMessage, 
               @ErrorSeverity,
               @ErrorState);
  END CATCH  
END
GO

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