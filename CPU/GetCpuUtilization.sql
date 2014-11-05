SET NOCOUNT ON

DECLARE @CPU TABLE (Output varchar(max))
DECLARE @Text varchar(20);
DECLARE @Utilization varchar(10);
INSERT INTO @CPU EXEC master.dbo.xp_cmdshell 'Powershell -Command Get-WmiObject win32_processor'
DELETE FROM @CPU WHERE output not like 'Load%'
SELECT @Text= 'CPU Utilization',
@Utilization=substring(output,charindex(' :',output)+2, len(output)) + ' %' FROM @CPU WHERE Output IS NOT NULL

PRINT @Text + ' : ' +@Utilization

SET NOCOUNT OFF
GO 10

