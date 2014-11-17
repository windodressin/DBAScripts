--GET BLOCKING AND BLCOKED DETAILS FROM BLOCKING EVENT TABLE
SELECT [BlockingEventData].value('(/EVENT_INSTANCE/PostTime)[1]', 'datetime') AS [BlockingEventTime] ,
[BlockingEventData].value('(/EVENT_INSTANCE/EventType)[1]', 'varchar(50)') AS [BlockingEventType] ,
CAST([BlockingEventData].value('(/EVENT_INSTANCE/Duration)[1]', 'bigint') / 1000000.0 AS [decimal](6, 2)) AS [BlockingDurationInSeconds] ,
[BlockingEventData].value('(/EVENT_INSTANCE/TextData/blocked-process-report/blocked-process/process/@waitresource)[1]', 'varchar(64)') AS [BlockedWaitResource] ,
DB_NAME([BlockingEventData].value('(/EVENT_INSTANCE/DatabaseID)[1]', 'int')) AS [BlockedWaitResourceDatabase] ,
[BlockingEventData].value('(/EVENT_INSTANCE/TextData/blocked-process-report/blocked-process/process/@spid)[1]', 'int') AS [BlockedProcessSPID] ,
[BlockingEventData].value('(/EVENT_INSTANCE/TextData/blocked-process-report/blocked-process/process/@loginname)[1]', 'varchar(64)') AS [BlockedProcessOwnerLoginName] ,
UPPER([BlockingEventData].value('(/EVENT_INSTANCE/TextData/blocked-process-report/blocked-process/process/@status)[1]', 'varchar(32)')) AS [BlockedProcessStatus] ,
[BlockingEventData].value('(/EVENT_INSTANCE/TextData/blocked-process-report/blocked-process/process/@lockMode)[1]', 'varchar(64)') AS [BlockedProcessLockMode] ,
UPPER([BlockingEventData].value('(/EVENT_INSTANCE/TextData/blocked-process-report/blocked-process/process/@transactionname)[1]', 'varchar(64)')) AS [BlockedProcessCommandType] ,
[BlockingEventData].value('(/EVENT_INSTANCE/TextData/blocked-process-report/blocked-process)[1]', 'varchar(max)') AS [BlockedProcessTSQL] ,
[BlockingEventData].value('(/EVENT_INSTANCE/TextData/blocked-process-report/blocked-process/process/@lastbatchstarted)[1]', 'datetime') AS [BlockedProcessLastBatchStartTime] ,
[BlockingEventData].value('(/EVENT_INSTANCE/TextData/blocked-process-report/blocked-process/process/@lastbatchcompleted)[1]', 'datetime') AS [BlockedProcessLastBatchCompleteTime] ,
UPPER([BlockingEventData].value('(/EVENT_INSTANCE/TextData/blocked-process-report/blocked-process/process/@isolationlevel)[1]', 'varchar(64)')) AS [BlockedProcessTransactionIsolationLevel] ,[BlockingEventData].value('(/EVENT_INSTANCE/TextData/blocked-process-report/blocked-process/process/@clientapp)[1]', 'varchar(128)') AS [BlockedProcessClientApplication] ,
[BlockingEventData].value('(/EVENT_INSTANCE/TextData/blocked-process-report/blocked-process/process/@hostname)[1]', 'varchar(64)') AS [BlockedProcessHostName] ,
[BlockingEventData].value('(/EVENT_INSTANCE/TextData/blocked-process-report/blocking-process/process/@spid)[1]', 'int') AS [BlockingProcessSPID] ,
[BlockingEventData].value('(/EVENT_INSTANCE/TextData/blocked-process-report/blocking-process/process/@loginname)[1]', 'varchar(64)') AS [BlockingProcessOwnerLoginName] ,
UPPER([BlockingEventData].value('(/EVENT_INSTANCE/TextData/blocked-process-report/blocking-process/process/@status)[1]', 'varchar(32)')) AS [BlockingProcessStatus] ,
[BlockingEventData].value('(/EVENT_INSTANCE/TextData/blocked-process-report/blocking-process)[1]', 'varchar(64)') AS [BlockingProcessTSQL] ,
[BlockingEventData].value('(/EVENT_INSTANCE/TextData/blocked-process-report/blocking-process/process/@lastbatchstarted)[1]', 'datetime') AS [BlockingProcessLastBatchStartTime] ,
[BlockingEventData].value('(/EVENT_INSTANCE/TextData/blocked-process-report/blocking-process/process/@lastbatchcompleted)[1]', 'datetime') AS [BlockingProcessLastBatchCompleteTime] ,
UPPER([BlockingEventData].value('(/EVENT_INSTANCE/TextData/blocked-process-report/blocking-process/process/@isolationlevel)[1]', 'varchar(64)')) AS [BlockingProcessTransactionIsolationLevel] ,[BlockingEventData].value('(/EVENT_INSTANCE/TextData/blocked-process-report/blocking-process/process/@clientapp)[1]', 'varchar(128)') AS [BlockingProcessClientApplication] ,
[BlockingEventData].value('(/EVENT_INSTANCE/TextData/blocked-process-report/blocking-process/process/@hostname)[1]', 'varchar(64)') AS [BlockingProcessHostName] ,
[BlockedProcessReport] FROM [DBA_STORE].[dbo].[BlockedProcessesEventLog] 

/*
This query returns the following columns:
•BlockingEventTime – Indicates the time of blocking event. 
•BlockingEventType – Specifies the type of event captured.
•BlockingDurationInSeconds – Specifies duration of blocking in seconds.
•BlockedWaitResource – The name of the resource request is waiting for.
•BlockedWaitResourceDatabase – The name of the database in which the requested resource exists.
•BlockedProcessSPID – The SPID of the waiting session.
•BlockedProcessOwnerLoginName – The user session login name under which waiting session is currently executing.
•BlockedProcessStatus – The status of waiting process.
•BlockedProcessLockMode – Mode of the wait request.
•BlockedProcessCommandType – The type of waiting session command.
•BlockedProcessTSQL - The text of waiting session command.
•BlockedProcessLastBatchStartTime – Specifies waiting process last batch start time.
•BlockedProcessLastBatchCompleteTime – Specifies waiting process last batch completion time.
•BlockedProcessTransactionIsolationLevel – Specifies waiting process transaction isolation level. 
•BlockedProcessClientApplication – The name of the program that initiated the waiting session.
•BlockedProcessHostName – The name of the workstation that is specific to waiting session.
•BlockingProcessSPID – The SPID of the blocking session.
•BlockingProcessOwnerLoginName – The user session login name under which blocking session is currently executing.
•BlockingProcessStatus – The status of blocking process.
•BlockingProcessTSQL – The text of blocking session command.
•BlockingProcessLastBatchStartTime – Specifies blocking process last batch start time.
•BlockingProcessLastBatchCompleteTime – Specifies blocking process last batch completion time.
•BlockingProcessTransactionIsolationLevel – Specifies blocking process transaction isolation level. 
•BlockingProcessClientApplication – The name of the program that initiated the blocking session.
•BlockingProcessHostName – The name of the workstation that is specific to blocking session.
- See more at: http://www.sswug.org/articles/viewarticle.aspx?id=69169#sthash.Qz538qxY.5bMZb6fs.dpuf
*/