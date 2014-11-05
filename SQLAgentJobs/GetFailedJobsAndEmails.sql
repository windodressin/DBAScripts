/* Looks for last SQL Agent job failures and emails DBA team */

---- send mail message -----
 IF ( SELECT  count(sysjobs.name)
	FROM msdb.dbo.sysjobs 
        INNER JOIN msdb.dbo.syscategories ON msdb.dbo.sysjobs.category_id = msdb.dbo.syscategories.category_id
        LEFT OUTER JOIN msdb.dbo.sysoperators ON msdb.dbo.sysjobs.notify_page_operator_id = msdb.dbo.sysoperators.id
        LEFT OUTER JOIN msdb.dbo.sysjobservers ON msdb.dbo.sysjobs.job_id = msdb.dbo.sysjobservers.job_id
        LEFT OUTER JOIN msdb.dbo.sysjobschedules ON msdb.dbo.sysjobschedules.job_id = msdb.dbo.sysjobs.job_id
        LEFT OUTER JOIN msdb.dbo.sysschedules ON msdb.dbo.sysschedules.schedule_id = msdb.dbo.sysjobschedules.schedule_id
	WHERE   sysjobs.enabled = 1 AND sysschedules.enabled = 1 AND sysjobservers.last_run_outcome = 0)
	> 0

BEGIN
SET NOCOUNT OFF
DECLARE @tableHTML1  NVARCHAR(MAX) ;

SET @tableHTML1 = 
    N'<H2>Failed SQL Agent Jobs' +
    --N'Total Number of Jobs failed: ' + CAST ((SELECT COUNT(*) FROM DBops_FailedJobs_OA  where datepart(dd,report_date) = (datepart(dd,getdate())))AS NVARCHAR(MAX) ) + 
    N'<table style = "font-family: Arial; font-size: 8pt" border = "1" cellspacing = "0" cellpadding = "2" width=80%>' +
    N'<tr style = "background-color: yellow; font-size: 10pt;"><th ALIGN="left">Server Name</th><th ALIGN="left">Job Name</th><th ALIGN="left">Last Run Date</th><th ALIGN="left">Job Step</th><th ALIGN="left">Message</th>' +
    CAST ( ( SELECT td = msdb.dbo.sysjobs.name,        '',
        td = msdb.dbo.sysjobs.name,        '',
        td = msdb.dbo.sysjobservers.last_run_date, '',
		td = msdb.dbo.sysjobhistory.step_id, ''--,
     --   td = msdb.dbo.sysjobhistory.message, ''
	FROM msdb.dbo.sysjobs
        INNER JOIN msdb.dbo.syscategories ON msdb.dbo.sysjobs.category_id = msdb.dbo.syscategories.category_id
        LEFT OUTER JOIN msdb.dbo.sysoperators ON msdb.dbo.sysjobs.notify_page_operator_id = msdb.dbo.sysoperators.id
        LEFT OUTER JOIN msdb.dbo.sysjobservers ON msdb.dbo.sysjobs.job_id = msdb.dbo.sysjobservers.job_id
        LEFT OUTER JOIN msdb.dbo.sysjobschedules ON msdb.dbo.sysjobschedules.job_id = msdb.dbo.sysjobs.job_id
        LEFT OUTER JOIN msdb.dbo.sysschedules ON msdb.dbo.sysschedules.schedule_id = msdb.dbo.sysjobschedules.schedule_id
		LEFT OUTER JOIN msdb.dbo.sysjobhistory ON msdb.dbo.sysjobs.job_id = msdb.dbo.sysjobhistory.job_id
	WHERE sysjobs.enabled = 1 AND sysschedules.enabled = 1 AND sysjobservers.last_run_outcome = 0 AND msdb.dbo.sysjobhistory.run_status = 0 
	    AND msdb.dbo.sysjobhistory.step_id <> 0
    FOR XML PATH('tr'), TYPE 
    ) AS NVARCHAR(MAX) ) +
    N'</table>';

DECLARE @subjectMessage varchar(255)
SELECT @subjectMessage = 'Failed ' + @@servername + 'SQL Agent Jobs'

EXEC msdb.dbo.sp_send_dbmail 
	@profile_name = 'SQL Server Notification',
	@recipients='svuong@carxrm.com',
	@subject = @subjectMessage,
    @body = @tableHTML1,
    @body_format = 'HTML' ;  

END ELSE 

BEGIN
SET NOCOUNT OFF

SET @tableHTML1 = 
    N'<H2>CARSQLSERVER Jobs Completed Successfully!</H2>' 
SELECT @subjectMessage = 'All Jobs Completed on  ' + @@servername
      
EXEC msdb.dbo.sp_send_dbmail 
	@profile_name =
	 'SQL Server Notification',
	@recipients='svuong@carxrm.com',
    @subject = @subjectMessage,
    @body = @tableHTML1,
    @body_format = 'HTML' ;  
END
---- send mail message -----


