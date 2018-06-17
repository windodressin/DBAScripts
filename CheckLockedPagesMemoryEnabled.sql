--Check if locked pages in memory is enabled!

SELECT locked_page_allocations_kb 
FROM sys.dm_os_process_memory