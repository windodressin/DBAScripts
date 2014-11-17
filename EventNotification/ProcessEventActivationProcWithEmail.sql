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
			---- send mail message -----
				SET NOCOUNT OFF
				DECLARE @tableHTML1  NVARCHAR(MAX) ;
				SET @EventTime = CAST(@message_body AS [xml]).value('(/EVENT_INSTANCE/PostTime)[1]', 'datetime')
				SET @Database = DB_NAME(CAST(@message_body AS [xml]).value('(/EVENT_INSTANCE/DatabaseID)[1]', 'int'))
				SET @EventType = CAST(@message_body.query('/EVENT_INSTANCE/EventType/text()') AS [nvarchar](128))
				SET @BlockedProcessReport = CAST(@message_body AS [xml]).query('(/EVENT_INSTANCE/TextData/blocked-process-report/.)[1]')



				SELECT @tableHTML1 = 
					N'<table style = "font-family: Arial; font-size: 8pt" border = "1" cellspacing = "0" cellpadding = "2" width=50%>' +
					N'<tr style = "background-color: blue; font-size: 10pt;"><th ALIGN="left">EventTime</th><th ALIGN="left">Database</th><th ALIGN="left">BlockedProcessReport</th>' +
					CAST ( ( SELECT td = @EventTime,        '',
					td = @Database,        '',
					td = @EventType,        '',
					td = @BlockedProcessReport,        ''
					FOR XML PATH('tr'), TYPE 
					) AS NVARCHAR(MAX) ) + N'</table>';

				DECLARE @subjectMessage varchar(255)
				DECLARE @alertEmail varchar(255)
				SELECT @subjectMessage = @@servername + ' Blocking Alert'

				SELECT @alertEmail = EMAIL	 
				FROM dba_store.dbo.JOB_AND_ALERT_CONTACT WITH (READUNCOMMITTED)
				WHERE CATEGORY = 'DATABASE' AND NotifyPrimary = 1


				EXEC msdb.dbo.sp_send_dbmail 
				@profile_name = 'SQL Server Notification',
				--@recipients='CRAIG@CARXRM.COM;SVUONG@CARXRM.COM;aengelbrecht@car-research.com',
				@recipients='SVUONG@CARXRM.COM',
				@subject = @subjectMessage,
				@body = @tableHTML1,
				@body_format = 'HTML' ;  
			---- send mail message -----
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