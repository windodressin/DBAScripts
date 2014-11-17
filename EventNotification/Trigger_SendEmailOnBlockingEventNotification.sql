--Email DBA on blocking event
USE DBA_STORE
GO

IF OBJECT_ID ('tr_BlockingNotificationToAdmin','TR') IS NOT NULL
   DROP TRIGGER tr_BlockingNotificationToAdmin
GO

CREATE TRIGGER tr_BlockingNotificationToAdmin
   ON  [dbo].[BlockedProcessesEventLog]
   AFTER INSERT
AS 
SET NOCOUNT OFF
DECLARE @tableHTML1  NVARCHAR(MAX) ;

SET @tableHTML1 = 
    N'<table style = "font-family: Arial; font-size: 8pt" border = "1" cellspacing = "0" cellpadding = "2" width=50%>' +
    N'<tr style = "background-color: blue; font-size: 10pt;"><th ALIGN="left">EventID</th><th ALIGN="left">Resource</th><th ALIGN="left">BlockingSPID</th><th ALIGN="left">BlockedProcessReport</th>' +
    CAST ( ( SELECT td = ID,        '',
  		td = [Resource],	'',
		td = BlockingSPID,	'',
		td = BlockedProcessReport,	''
	--FROM [dbo].[BlockedProcessesEventLog] 
	FROM INSERTED
    FOR XML PATH('tr'), TYPE 
    ) AS NVARCHAR(MAX) ) +
    N'</table>';

DECLARE @subjectMessage varchar(255)
DECLARE @alertEmail varchar(255)
SELECT @subjectMessage = @@servername + ' Blocking Alert'

SELECT @alertEmail = EMAIL	 
FROM dba_store.dbo.JOB_AND_ALERT_CONTACT WITH (READUNCOMMITTED)
WHERE CATEGORY = 'DATABASE' AND NotifyPrimary = 1

EXEC msdb.dbo.sp_send_dbmail 
	@profile_name = 'SQL Server Notification',
	@recipients=@alertEmail,
	@subject = @subjectMessage,
    @body = @tableHTML1,
    @body_format = 'HTML' ;  
---- send mail message -----

/*
--GET BLOCKING AND BLCOKED DETAILS FROM BLOCKING EVENT TABLE
SELECT 
EventRowID,
[BlockingEventData].value('(/EVENT_INSTANCE/PostTime)[1]', 'datetime') AS [BlockingEventTime] ,
[BlockingEventData].value('(/EVENT_INSTANCE/TextData/blocked-process-report/blocked-process/process/@spid)[1]', 'int') AS [BlockedProcessSPID] ,
[BlockingEventData].value('(/EVENT_INSTANCE/TextData/blocked-process-report/blocking-process/process/@spid)[1]', 'int') AS [BlockingProcessSPID] ,
DB_NAME([BlockingEventData].value('(/EVENT_INSTANCE/DatabaseID)[1]', 'int')) AS [BlockedWaitResourceDatabase] 
FROM INSERTED --[dbo].[BlockedProcessesEventLog] 
*/




