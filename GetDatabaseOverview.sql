--Get user database overview

CREATE TABLE #helpdb 
			(
			 name varchar(50),
			 db_size varchar(50),
			 owner varchar(50),
			 dbid int,
			 created varchar(25),
			 status varchar(255),
			 compat int
			)

INSERT INTO #helpdb EXEC sp_helpdb

SELECT 
	sdb.name AS DatabaseName,
	sdb.state_desc AS DatabaseState,
	hdb.db_size AS Size,
	hdb.owner AS Owner,
	sdb.compatibility_level AS Compatibility,
	sdb.recovery_model_desc AS RecoveryModel,
	hdb.created AS CreateDate,
	sdb.is_query_store_on AS QueryStoreOn,
	sdb.collation_name AS CollationName,
	sdb.snapshot_isolation_state_desc AS SnapshotIsolationState,
	sdb.is_read_committed_snapshot_on AS ReadCommittedSnapshot,
	sdb.target_recovery_time_in_seconds AS TargetRecoveryTimeInSeconds
FROM sys.databases sdb JOIN #helpdb hdb ON sdb.database_id = hdb.dbid
WHERE sdb.database_id > 4

DROP TABLE #helpdb;
				

				