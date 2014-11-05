--Pending_disk_io_count displays the tasks that are yet to be processed in the scheduler. For better processing, this count is expected not to be very high.
SELECT
	scheduler_id,
	cpu_id,
	current_tasks_count,
	runnable_tasks_count,
	current_workers_count,
	active_workers_count,
	work_queue_count,
	pending_disk_io_count
FROM 
	sys.dm_os_schedulers
WHERE 
	scheduler_id < 255; 