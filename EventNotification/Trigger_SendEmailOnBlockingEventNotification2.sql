USE [DBA_STORE]
GO

/****** Object:  Trigger [tr_BlockingNotificationToAdmin]    Script Date: 11/13/2014 4:02:04 PM ******/
DROP TRIGGER [dbo].[tr_BlockingNotificationToAdmin]
GO

/****** Object:  Trigger [dbo].[tr_BlockingNotificationToAdmin]    Script Date: 11/13/2014 4:02:04 PM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


CREATE TRIGGER [dbo].[tr_BlockingNotificationToAdmin]
   ON  [dbo].[BlockedProcessesEventLog]
   AFTER INSERT
AS 
SET NOCOUNT OFF
DECLARE @tableHTML1  NVARCHAR(MAX) ;

SET @tableHTML1 = 
    N'<table style = "font-family: Arial; font-size: 8pt" border = "1" cellspacing = "0" cellpadding = "2" width=70%>' +
    N'<tr style = "background-color: blue; font-size: 10pt;">
	<th ALIGN="left">EventID</th>
	<th ALIGN="left">Database</th>
	<th ALIGN="left">BlockingSPID</th>
	<th ALIGN="left">BlockedSPID</th>
	<th ALIGN="left">BlockingSQL</th>
	<th ALIGN="left">BlockedProcessReport</th>' +
    CAST ( ( SELECT td = ID,        '',
  		td = DB_NAME(DatabaseID),	'',
		td = BlockingSPID,	'',
		td = BlockedSPID,	'',
		td = BlockingInputBuf,  '',
		td = BlockedProcessReport,	''
	--FROM [dbo].[BlockedProcessesEventLog] 
	FROM INSERTED
    FOR XML PATH('tr'), TYPE 
    ) AS NVARCHAR(MAX) ) +
    N'</table>';

DECLARE @EventID int
DECLARE @subjectMessage varchar(255)
DECLARE @alertEmail varchar(255)
SELECT @subjectMessage = @@servername + ' Blocking Alert'
SELECT @EventID = ID FROM INSERTED

SELECT @alertEmail = EMAIL	 
FROM dba_store.dbo.JOB_AND_ALERT_CONTACT WITH (READUNCOMMITTED)
WHERE CATEGORY = 'DATABASE' AND NotifyPrimary = 1

EXEC msdb.dbo.sp_send_dbmail 
	@profile_name = 'SQL Server Notification',
	--@recipients='craig@carxrm.com;aengelbrecht@car-research.com;svuong@carxrm.com',
	@recipients=@alertEmail,
	@subject = @subjectMessage,
    @body = @tableHTML1,
	@body_format = 'HTML',
	@query =  'SET NOCOUNT ON
			   DECLARE @ID int
			   SELECT @ID = max(id) FROM DBA_STORE..BlockedProcessesEventLog
			   SELECT ''SELECT * FROM [dbo].[BlockedProcessesEventLog] WHERE ID = '' + CAST(ID AS varchar(5)) 
					    FROM DBA_STORE..BlockedProcessesEventLog WHERE ID = @ID'; 
	--Added Query to body of email to save on typing! 

/*
--GET BLOCKING AND BLOCKED DETAILS FROM BLOCKING EVENT TABLE
SELECT 
EventRowID,
[BlockingEventData].value('(/EVENT_INSTANCE/PostTime)[1]', 'datetime') AS [BlockingEventTime] ,
[BlockingEventData].value('(/EVENT_INSTANCE/TextData/blocked-process-report/blocked-process/process/@spid)[1]', 'int') AS [BlockedProcessSPID] ,
[BlockingEventData].value('(/EVENT_INSTANCE/TextData/blocked-process-report/blocking-process/process/@spid)[1]', 'int') AS [BlockingProcessSPID] ,
DB_NAME([BlockingEventData].value('(/EVENT_INSTANCE/DatabaseID)[1]', 'int')) AS [BlockedWaitResourceDatabase] 
FROM INSERTED --[dbo].[BlockedProcessesEventLog] 
*/






GO


