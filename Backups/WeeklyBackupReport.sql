/**
USE msdb
GO
SELECT bs.server_name AS Server,
       bs.database_name AS DatabseName,
       CONVERT(varchar(20), bs.backup_start_date, 113) AS BackupstartDate,
       DATEDIFF(mi, bs.backup_start_date, bs.backup_finish_date) AS RunTimeInMinutes
 FROM   msdb.dbo.backupset bs 
       INNER JOIN msdb.dbo.backupmediafamily bmf 
               ON ( bs.media_set_id = bmf.media_set_id ) 
WHERE bs.backup_start_date >  DATEADD(dd, -6, getdate())            
ORDER  BY bs.backup_start_date ASC
GO
**/ 


DECLARE @tableHTML1  NVARCHAR(MAX) ;
SET @tableHTML1 = 
  
    N'<table style = "font-family: Arial; font-size: 8pt" border = "1" cellspacing = "0" cellpadding = "2" width=100%>' +
    N'<tr style = "background-color: blue; font-size: 10pt;"><th ALIGN="left">Server Name</th><th ALIGN="left">Database Name</th><th ALIGN="left">Backup Start Time</th><th ALIGN="left">Backup Runtime (Mins)</th>' +
    CAST ( ( SELECT td = bs.server_name, '',
					td = bs.database_name, '',
				    td = CONVERT(varchar(20), bs.backup_start_date, 113),'',
				    td = DATEDIFF(mi, bs.backup_start_date, bs.backup_finish_date),''
			FROM  msdb.dbo.backupset bs 
			INNER JOIN msdb.dbo.backupmediafamily bmf 
            ON ( bs.media_set_id = bmf.media_set_id ) 
			WHERE bs.backup_start_date >  DATEADD(dd, -6, getdate())            
			ORDER  BY bs.backup_start_date ASC
            FOR XML PATH('tr'), TYPE 
    ) AS NVARCHAR(MAX) ) +
    N'</table>';

EXEC msdb.dbo.sp_send_dbmail 
	@profile_name = 'SQLAlerts',
	@recipients='svuong@carxrm.com',

    @subject = 'Weekly Backup Report',
    @body = @tableHTML1,
    @body_format = 'HTML' 
 
 
