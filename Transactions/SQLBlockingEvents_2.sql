USE msdb
GO

EXEC sp_configure 'show advanced options', 1
RECONFIGURE
GO
EXEC sp_configure 'blocked process threshold', 30
RECONFIGURE
GO

CREATE QUEUE BlockedProcessQueue

CREATE SERVICE BlockedProcessService ON QUEUE BlockedProcessQueue ([http://schemas.microsoft.com/SQL/Notifications/PostEventNotification])
GO

USE master
GO

CREATE FUNCTION [dbo].[wait_resource_name](@obj nvarchar(max))
RETURNS @wait_resource TABLE (
    wait_resource_database_name sysname,
    wait_resource_schema_name sysname,
    wait_resource_object_name sysname
)
AS
BEGIN
    DECLARE @dbid int
    DECLARE @objid int

    IF @obj IS NULL RETURN
    IF @obj NOT LIKE 'OBJECT: %' RETURN

    SET @obj = SUBSTRING(@obj, 9, LEN(@obj) - 9 + CHARINDEX(':', @obj, 9))

    SET @dbid = LEFT(@obj, CHARINDEX(':', @obj, 1) - 1)
    SET @objid = SUBSTRING(@obj, CHARINDEX(':', @obj, 1) + 1, CHARINDEX(':', @obj, CHARINDEX(':', @obj, 1) + 1) - CHARINDEX(':', @obj, 1) - 1)

    INSERT INTO @wait_resource (wait_resource_database_name, wait_resource_schema_name, wait_resource_object_name)
    SELECT db_name(@dbid), object_schema_name(@objid, @dbid), object_name(@objid, @dbid)

    RETURN
END
GO

CREATE PROCEDURE StartBlockedProcessNotification
AS
CREATE EVENT NOTIFICATION BlockedProcessNotification ON SERVER FOR BLOCKED_PROCESS_REPORT TO SERVICE 'BlockedProcessService', 'current database'
GO

EXEC sp_procoption 'StartBlockedProcessNotification', 'startup', 'on'
EXEC StartBlockedProcessNotification

USE msdb
GO

CREATE PROCEDURE BlockedProcessActivationProcedure
AS

--Service Broker
DECLARE @message_body xml
DECLARE @message_body_text nvarchar(max)
DECLARE @dialog uniqueidentifier
DECLARE @message_type nvarchar(256)

WHILE 1 = 1
BEGIN --Process the queue
    BEGIN TRANSACTION;

    RECEIVE TOP (1)
        @message_body = message_body,
        @dialog = conversation_handle,
        @message_type = message_type_name
    FROM BlockedProcessQueue

    IF @@ROWCOUNT = 0
    BEGIN
        RAISERROR('Nothing more to process', 0, 1)
        ROLLBACK TRANSACTION
        RETURN
    END

    IF @message_type = 'http://schemas.microsoft.com/SQL/Notifications/EventNotification'
    BEGIN
        DECLARE @mail_body nvarchar(max)

        DECLARE @post_time varchar(32)
        DECLARE @duration int
        DECLARE @blocked_spid int
        DECLARE @waitresource nvarchar(max)
        DECLARE @waitresource_db nvarchar(128)
        DECLARE @waitresource_schema nvarchar(128)
        DECLARE @waitresource_name nvarchar(128)
        DECLARE @blocked_hostname nvarchar(128)
        DECLARE @blocked_db nvarchar(128)
        DECLARE @blocked_login nvarchar(128)
        DECLARE @blocked_lasttranstarted nvarchar(32)
        DECLARE @blocked_inputbuf nvarchar(max)
        DECLARE @blocking_spid int
        DECLARE @blocking_hostname nvarchar(128)
        DECLARE @blocking_db nvarchar(128)
        DECLARE @blocking_login nvarchar(128)
        DECLARE @blocking_lasttranstarted nvarchar(32)
        DECLARE @blocking_inputbuf nvarchar(max)

        SET @post_time = CONVERT(varchar(32), @message_body.value(N'(//EVENT_INSTANCE/PostTime)[1]', 'datetime'), 109)
        SET @duration = CAST(@message_body.value(N'(//EVENT_INSTANCE/Duration)[1]', 'bigint') / 1000000 AS int)
        SET @blocked_spid = @message_body.value(N'(//EVENT_INSTANCE/TextData/blocked-process-report/blocked-process/process/@spid)[1]', 'int')
        SET @waitresource = @message_body.value(N'(//EVENT_INSTANCE/TextData/blocked-process-report/blocked-process/process/@waitresource)[1]', 'nvarchar(max)')
        SET @blocked_hostname = @message_body.value(N'(//EVENT_INSTANCE/TextData/blocked-process-report/blocked-process/process/@hostname)[1]', 'nvarchar(128)')
        SET @blocked_db = DB_NAME(@message_body.value(N'(//EVENT_INSTANCE/TextData/blocked-process-report/blocked-process/process/@currentdb)[1]', 'int'))
        SET @blocked_login = @message_body.value(N'(//EVENT_INSTANCE/TextData/blocked-process-report/blocked-process/process/@loginname)[1]', 'nvarchar(128)')
        SET @blocked_lasttranstarted = CONVERT(varchar(32), @message_body.value(N'(//EVENT_INSTANCE/TextData/blocked-process-report/blocked-process/process/@lasttranstarted)[1]', 'datetime'), 109)
        SET @blocked_inputbuf = @message_body.value(N'(//EVENT_INSTANCE/TextData/blocked-process-report/blocked-process/process/inputbuf)[1]', 'nvarchar(max)')
        SET @blocking_spid = @message_body.value(N'(//EVENT_INSTANCE/TextData/blocked-process-report/blocking-process/process/@spid)[1]', 'int')
        SET @blocking_hostname = @message_body.value(N'(//EVENT_INSTANCE/TextData/blocked-process-report/blocking-process/process/@hostname)[1]', 'nvarchar(128)')
        SET @blocking_db = DB_NAME(@message_body.value(N'(//EVENT_INSTANCE/TextData/blocked-process-report/blocking-process/process/@currentdb)[1]', 'int'))
        SET @blocking_login = @message_body.value(N'(//EVENT_INSTANCE/TextData/blocked-process-report/blocking-process/process/@loginname)[1]', 'nvarchar(128)')
        SET @blocking_lasttranstarted = CONVERT(varchar(32), @message_body.value(N'(//EVENT_INSTANCE/TextData/blocked-process-report/blocking-process/process/@lasttranstarted)[1]', 'datetime'), 109)
        SET @blocking_inputbuf = @message_body.value(N'(//EVENT_INSTANCE/TextData/blocked-process-report/blocking-process/process/inputbuf)[1]', 'nvarchar(max)')

        SELECT
            @waitresource_name = wait_resource_object_name,
            @waitresource_schema = wait_resource_schema_name,
            @waitresource_db = wait_resource_database_name
        FROM master.dbo.wait_resource_name(@waitresource)

        SET @mail_body = 'Posted: ' + ISNULL(@post_time, '') + CHAR(10) +
            'Duration: ' + ISNULL(CAST(@duration AS varchar) + ' s', '') + CHAR(10) +
            CHAR(10) +
            '==========Blocked Process==========' + CHAR(10) +
            'SPID: ' + ISNULL(CAST(@blocked_spid AS varchar), '') + CHAR(10) +
            'Wait Resource: ' + ISNULL(ISNULL(QUOTENAME(@waitresource_db) + '.' + QUOTENAME(@waitresource_schema) + '.' + QUOTENAME(@waitresource_name), @waitresource), '') + CHAR(10) +
            'Hostname: ' + ISNULL(@blocked_hostname, '') + CHAR(10) +
            'Current Database: ' + ISNULL(@blocked_db, '') + CHAR(10) +
            'Login Name: ' + ISNULL(@blocked_login, '') + CHAR(10) +
            'Last Transaction Started: ' + ISNULL(@blocked_lasttranstarted, '') + CHAR(10) +
            '----------Input Buffer----------' + CHAR(10) +
            ISNULL(@blocked_inputbuf, '') + CHAR(10) +
            CHAR(10) +
            '==========Blocking Process==========' + CHAR(10) +
            'SPID: ' + ISNULL(CAST(@blocking_spid AS varchar), '') + CHAR(10) +
            'Hostname: ' + ISNULL(@blocking_hostname, '') + CHAR(10) +
            'Current Database: ' + ISNULL(@blocking_db, '') + CHAR(10) +
            'Login Name: ' + ISNULL(@blocking_login, '') + CHAR(10) +
            'Last Transaction Started: ' + ISNULL(@blocking_lasttranstarted, '') + CHAR(10) +
            '----------Input Buffer----------' + CHAR(10) +
            ISNULL(@blocking_inputbuf, '') + CHAR(10)

        EXEC sp_send_dbmail @recipients = 'Your address here', @subject = 'Blocked Process Report', @body = @mail_body
    END
    ELSE IF @message_type IN ('http://schemas.microsoft.com/SQL/ServiceBroker/Error', 'http://schemas.microsoft.com/SQL/ServiceBroker/EndDialog')
    BEGIN
        END CONVERSATION @dialog
    END

    COMMIT TRANSACTION
END

GO

ALTER QUEUE BlockedProcessQueue WITH ACTIVATION (
    STATUS = ON,
    PROCEDURE_NAME = [BlockedProcessActivationProcedure],
    MAX_QUEUE_READERS = 1,
    EXECUTE AS OWNER