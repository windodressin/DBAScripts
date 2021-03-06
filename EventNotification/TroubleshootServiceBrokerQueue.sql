/****** Script for SelectTopNRows command from SSMS  ******/
SELECT TOP 1000 *, casted_message_body = 
CASE message_type_name WHEN 'X' 
  THEN CAST(message_body AS NVARCHAR(MAX)) 
  ELSE message_body 
END 
FROM [DBA_STORE].[dbo].[BlockedProcessReportQueue] WITH(NOLOCK)



 

SELECT s.name as 'Service', q.name as 'Queue', q.is_receive_enabled, q.is_activation_enabled, q.activation_procedure
FROM   sys.services s
JOIN   sys.service_queues q
ON     s.service_queue_id = q.object_id
WHERE  q.is_ms_shipped = 0

---
 SELECT * FROM sys.dm_broker_activated_tasks

 --

 SELECT q.name, m.*

FROM sys.dm_broker_queue_monitors m

JOIN sys.service_queues q

ON m.queue_id = q.object_id
