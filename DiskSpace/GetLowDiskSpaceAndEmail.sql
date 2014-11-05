/* Email DBA if disk space is low */

--Alert if Disk Space is less than 1GB. ---
SELECT DISTINCT dovs.logical_volume_name AS LogicalName,
			    dovs.volume_mount_point AS Drive,
			    CONVERT(INT,dovs.available_bytes/1048576.0) AS FreeSpaceInMB
INTO ##DiskSpace
FROM sys.master_files mf
CROSS APPLY sys.dm_os_volume_stats(mf.database_id, mf.FILE_ID) dovs

---- send mail message -----
 IF (SELECT COUNT(FreeSpaceInMB) FROM ##DiskSpace WHERE FreeSpaceInMB <= 1024)
	> 0

BEGIN
SET NOCOUNT OFF
DECLARE @tableHTML1  NVARCHAR(MAX) ;


SET @tableHTML1 = 
    N'<table style = "font-family: Arial; font-size: 8pt" border = "1" cellspacing = "0" cellpadding = "2" width=50%>' +
    N'<tr style = "background-color: blue; font-size: 10pt;"><th ALIGN="left">Logical Name</th><th ALIGN="left">Drive</th><th ALIGN="left">Free Space In MB</th>' +
    CAST ( ( SELECT td = LogicalName,        '',
        td = Drive,        '',
        td = FreeSpaceInMB, ''

	FROM ##DiskSpace
    WHERE FreeSpaceInMB <= 1024
    FOR XML PATH('tr'), TYPE 
    ) AS NVARCHAR(MAX) ) +
    N'</table>';

DECLARE @subjectMessage varchar(255)
DECLARE @alertEmail varchar(255)
SELECT @subjectMessage = @@servername + ' Low Disk Space Alert'

SELECT @alertEmail = EMAIL	 
FROM dba_store.dbo.JOB_AND_ALERT_CONTACT WITH (READUNCOMMITTED)
WHERE CATEGORY = 'DATABASE' AND NotifyPrimary = 1

EXEC msdb.dbo.sp_send_dbmail 
	@profile_name = 'SQL Server Notification',
	@recipients=@alertEmail,
	@subject = @subjectMessage,
    @body = @tableHTML1,
    @body_format = 'HTML' ;  

END ELSE 
BEGIN
PRINT 'All Good!'
END

DROP TABLE ##DiskSpace
---- send mail message -----



