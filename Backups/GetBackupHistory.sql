------------------------
/* Get Backup History */
------------------------


USE msdb 
GO 

SELECT bs.server_name           AS Server,-- Server name 
       bs.database_name         AS DatabseName,-- Database name 
       CASE bs.compatibility_level 
         WHEN 80 THEN 'SQL Server 2000' 
         WHEN 90 THEN 'SQL Server 2005 ' 
         WHEN 100 THEN 'SQL Server 2008' 
         WHEN 110 THEN 'SQL Server 2011' 
       END                      AS CompatibilityLevel, 
       -- Return backup compatibility level 
       recovery_model           AS Recoverymodel,-- Database recovery model 
       CASE bs.type 
         WHEN 'D' THEN 'Full' 
         WHEN 'I' THEN 'Differential' 
         WHEN 'L' THEN 'Log' 
         WHEN 'F' THEN 'File or filegroup' 
         WHEN 'G' THEN 'Differential file' 
         WHEN 'P' THEN 'P' 
         WHEN 'Q' THEN 'Differential partial' 
       END                      AS BackupType,-- Type of database baclup 
       bs.backup_start_date     AS BackupstartDate,-- Backup start date 
       bs.backup_finish_date    AS BackupFinishDate,-- Backup finish date 
       bmf.physical_device_name AS PhysicalDevice,-- baclup Physical localtion 
       CASE device_type 
         WHEN 2 THEN 'Disk - Temporary' 
         WHEN 102 THEN 'Disk - Permanent' 
         WHEN 5 THEN 'Tape - Temporary' 
         WHEN 105 THEN 'Tape - Temporary' 
         ELSE 'Other Device' 
       END                      AS DeviceType,-- Device type 
       bs.backup_size           AS [BackupSize(In bytes)], 
       -- Normal backup size (In bytes) 
       compressed_backup_size   AS [ConmpressedBackupSize(In bytes)] 
-- Compressed backup size (In bytes) 
FROM   msdb.dbo.backupset bs 
       INNER JOIN msdb.dbo.backupmediafamily bmf 
               ON ( bs.media_set_id = bmf.media_set_id ) 
ORDER  BY bs.backup_start_date DESC 
GO 