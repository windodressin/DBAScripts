
/***************************************************************************************************************************************

Creates a step to clean up output files if it does not exists as part of the backup job.

Assumptions:
			1: cpn_backupDB is used to initiate backups. This is to differentiate jobs using the work "backup" for non-database backups.
			2: The F:\DBA folder exists.  This is the output folder used in the backup scripts.

****************************************************************************************************************************************/



SET NOCOUNT ON

DECLARE @jobid uniqueidentifier,
	    @stepname sysname,
	    @stepcommand nvarchar(255),
	    @onsuccessaction tinyint,
		@subsystemtype varchar(10),
		@stepid int, 
		@on_success_action tinyint;

SELECT @stepname = 'Delete Output File'
SELECT @stepcommand = 'get-item ''F:\DBA\$(ESCAPE_NONE(JOBNAME))*.txt'' | where { $_.LastWriteTime -le (get-date).AddDays(-8) } | remove-item -force'
SELECT @subsystemtype = 'PowerShell'

DECLARE curBackups CURSOR FOR   
SELECT DISTINCT sj.job_id, sjs.step_id
FROM msdb..sysjobs sj JOIN msdb..sysjobsteps sjs 
ON sj.job_id=sjs.job_id
WHERE sj.name LIKE '%backup%' 
AND sjs.command LIKE '%cpn_backupDB%'  

OPEN curBackups  

FETCH NEXT FROM curBackups   
INTO @jobid, @stepid  

/**
SELECT @jobid = sj.job_id
FROM msdb..sysjobs sj JOIN msdb..sysjobsteps sjs 
ON sj.job_id=sjs.job_id
WHERE sj.name LIKE '%backup%' 
--AND sjs.command LIKE '%cpn_backupDB%'

SELECT @stepid = sjs.step_id
FROM msdb..sysjobs sj JOIN msdb..sysjobsteps sjs 
ON sj.job_id=sjs.job_id
WHERE sj.job_id = @jobid AND sjs.step_id = 1
**/

WHILE @@FETCH_STATUS = 0 
--check if job step to delete output exists 
BEGIN
IF @jobid IS NOT NULL
	IF NOT EXISTS(SELECT sjs.job_id 
				  FROM msdb..sysjobs sj join msdb..sysjobsteps sjs 
				  ON sj.job_id=sjs.job_id 
				  WHERE sj.job_id = @jobid 
				  AND sjs.step_name LIKE '%output%')
		BEGIN
			SELECT '-----Output file delete step does not exists!  Adding step now.-----' AS Message
			--Add step to delete output file
			EXEC msdb..sp_add_jobstep @job_id=@jobid, @step_name=@stepname, @subsystem=@subsystemtype, @command=@stepcommand


			SELECT '-----Modify previous step in Backup job to ''Go to Next Step on Success''-----' AS Message
			EXEC msdb..sp_update_jobstep @job_id=@jobid, @step_id=@stepid, @on_success_action=3

			SELECT '-----Please verify newly created job step below-----' AS Message
			SELECT sj.name AS JobName, 
				   sjs.step_name AS StepName, 
				   sjs.step_id AS StepID, 
				   sjs.subsystem AS SubSystem, 
				   sjs.command AS Command 
			FROM msdb..sysjobs sj JOIN msdb..sysjobsteps sjs 
			ON sj.job_id=sjs.job_id
			WHERE sj.job_id = @jobid
		END
	ELSE
		BEGIN
			SELECT '-----Output file delete step already exists! See below...-----' AS Message
			SELECT sj.name AS JobName, 
				   sjs.step_name AS StepName, 
				   sjs.step_id AS StepID, 
				   sjs.subsystem AS SubSystem, 
				   sjs.command AS Command 
			FROM msdb..sysjobs sj JOIN msdb..sysjobsteps sjs 
			ON sj.job_id=sjs.job_id
			WHERE sj.job_id = @jobid
		END
END

CLOSE curBackups;  
DEALLOCATE curBackups;  


--sp_help sp_add_jobstep 
--sp_help sp_update_jobstep
--sp_help sysjobs





