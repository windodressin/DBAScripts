 --Get list of possibly unused SPs (SQL 2008 only)
    SELECT p.name AS 'SP Name'        -- Get list of all SPs in the current database
    FROM sys.procedures AS p
    WHERE p.is_ms_shipped = 0

    EXCEPT

    SELECT p.name AS 'SP Name'        -- Get list of all SPs from the current database 
    FROM sys.procedures AS p          -- that are in the procedure cache
    INNER JOIN sys.dm_exec_procedure_stats AS qs
    ON p.object_id = qs.object_id
    WHERE p.is_ms_shipped = 0;