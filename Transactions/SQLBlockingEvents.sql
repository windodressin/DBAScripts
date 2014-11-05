--Show Advanced option
sp_configure 'show advanced options', 1
 go
 reconfigure
 go
 sp_configure
 go
 
--  Now, set the blocked process threshold to 10 seconds
 sp_configure 'blocked process threshold', 20
 go
 reconfigure WITH OVERRIDE
 go
 
 --  Create a service broker queue to hold the events
 CREATE QUEUE SQLBlockingEvents 
go

--  Create a service broker service receive the events
CREATE SERVICE [//CAR.net/BlockingEventsService]
 AUTHORIZATION [dbo]
 ON QUEUE [dbo].[SQLBlockingEvents] 
([http://schemas.microsoft.com/SQL/Notifications/PostEventNotification])
 GO
 
 --CREATE Notification
USE [DBA_STORE]
 GO
 
EXECUTE AS LOGIN = 'sa';
 DECLARE @AuditServiceBrokerGuid [uniqueidentifier]
 ,@SQL [varchar](max);
 
-- Retrieving the service broker guid of CaptureDeadlockGraph database
 SELECT @AuditServiceBrokerGuid = [service_broker_guid]
 FROM [master].[sys].[databases]
 WHERE [name] = 'DBA_STORE'
 
-- Building and executing dynamic SQL to create event notification objects
 -- Dynamic SQL to create eAuditLoginNotification event notification object
 
SET @SQL = 'IF EXISTS (SELECT * FROM sys.server_event_notifications 
WHERE name = ''BlockingEventNotification'')
 
DROP EVENT NOTIFICATION BlockingEventNotification ON SERVER 

CREATE EVENT NOTIFICATION BlockingEventNotification 
ON SERVER
 WITH fan_in
 FOR BLOCKED_PROCESS_REPORT
 TO SERVICE ''//CAR.net/BlockingEventsService'', '''
 + CAST(@AuditServiceBrokerGuid AS [varchar](50)) + ''';'
 EXEC (@SQL)
 GO

--Verify Service
SELECT * FROM sys.server_event_notifications

--Get Results of Blocking
SELECT cast( message_body as xml ), *
 FROM SQLBlockingEvents
 --OR--
USE dba_store;
WAITFOR(
   RECEIVE CAST(message_body AS XML), * 
   FROM  SQLBlockingEvents);


--build message for email if needed
DECLARE @msgs TABLE (   message_body xml not null,
                        message_sequence_number int not null );
  
RECEIVE message_body, message_sequence_number
FROM SQLBlockingEvents
INTO @msgs;
 
SELECT message_body, 
       DatabaseId = cast( message_body as xml ).value( '(/EVENT_INSTANCE/DatabaseID)[1]', 'int' ),
       Process    = cast( message_body as xml ).query( '/EVENT_INSTANCE/TextData/blocked-process-report/blocked-process/process' )
FROM @msgs
ORDER BY message_sequence_number



