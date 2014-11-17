
--Top resource consuming queries  
--Return top resource consuming queries

-- 1 Top 10 SQL statements with high Execution count
print '1. Top 10 SQL statements with high Execution count'
select top 10
    qs.execution_count,
    st.dbid,
    DB_NAME(st.dbid) as DbName,
    st.text
from sys.dm_exec_query_stats as qs
cross apply sys.dm_exec_sql_text(sql_handle) st
order by execution_count desc
go

 

-- 2 Top 10 SQL statements with high Duration
print '2. Top 10 SQL statements with high Duration'
select top 10
    qs.total_elapsed_time,
    st.dbid,
    DB_NAME(st.dbid) as DbName,
    st.text
from sys.dm_exec_query_stats as qs
cross apply sys.dm_exec_sql_text(sql_handle) st
order by total_elapsed_time desc
go

 

-- 3 Top 10 SQL statements with high CPU consumption
print '3. Top 10 SQL statements with high CPU consumption'
select top 10
    qs.sql_handle,
    qs.total_worker_time,
    st.dbid,
    DB_NAME(st.dbid) as DbName,
    st.text
from sys.dm_exec_query_stats as qs
cross apply sys.dm_exec_sql_text(sql_handle) st
order by total_worker_time desc
go

 
-- 4 Top 10 SQL statements with high Reads consumption
print '4. Top 10 SQL statements with high Reads consumption'
select top 10
    qs.total_logical_reads,
    st.dbid,
    DB_NAME(st.dbid) as DbName,
    st.text
from sys.dm_exec_query_stats as qs
cross apply sys.dm_exec_sql_text(sql_handle) st
order by total_logical_reads desc
go

 

-- 5 Top 10 SQL statements with high Writes consumption
print '5. Top 10 SQL statements with high Writes consumption'
select top 10
    qs.total_logical_writes,
    st.dbid,
    DB_NAME(st.dbid) as DbName,
    st.text
from sys.dm_exec_query_stats as qs
cross apply sys.dm_exec_sql_text(sql_handle) st
order by total_logical_writes desc
go

 

-- 6 Top 10 SQL statements with excessive compiles/recompiles.
print '6. Top 10 SQL statements with excessive compiles/recompiles'
select top 10
    qs.plan_generation_num, -- plan_generation_num column indicates the number of times the statements has recompiled.
    st.dbid,
    DB_NAME(st.dbid) as DbName,
    st.text
from sys.dm_exec_query_stats qs
cross apply sys.dm_exec_sql_text(sql_handle) as st
order by plan_generation_num desc
go

 

-- 7 locate queries that consume a large amount of log space
print '7. Queries that consume a large amount of log space'
select TOP(10)
    T1.database_id,
    DB_NAME(T1.database_id) as DbName,
    T4.text,
    T1.database_transaction_begin_time,
    T1.database_transaction_state,
    T1.database_transaction_log_bytes_used_system,
    T1.database_transaction_log_bytes_reserved,
    T1.database_transaction_log_bytes_reserved_system,
    T1.database_transaction_log_record_count
from sys.dm_tran_database_transactions T1
join sys.dm_tran_session_transactions T2 on T2.transaction_id = T1.transaction_id
join sys.dm_exec_requests T3 on T3.session_id = T2.session_id
cross apply sys.dm_exec_sql_text(T3.sql_handle) T4
--where T1.database_transaction_state = 4 -- 4 : The transaction has generated log records.
--and T1.database_id = db_id()
order by T1.database_transaction_log_record_count desc
--order by T1.database_transaction_log_bytes_reserved desc
go

 

 
Unused / Missing indexes  
 
 Return unused and missing indexes

 

 

-- Return unused indexes

-- Note : run this query against target database (not against master database)

print 'Unused indexes list'

 

select

    DB_NAME() as DbName,

    object_name(I.object_id) as TableName,

    I.name as IndexName,

    I.index_id,

    I.type_desc,

    I.is_primary_key

from sys.indexes I

left join sys.dm_db_index_usage_stats U on U.object_id = I.object_id and U.index_id = I.index_id and U.database_id = DB_ID()

where OBJECTPROPERTY(I.object_id,'IsUserTable') = 1

and U.user_seeks is null

and U.user_scans is null

and U.user_lookups is null

and U.last_user_seek is null

and U.last_user_scan is null

and U.last_user_lookup is null

and U.system_seeks is null

and U.system_scans is null

and U.system_lookups is null

and U.last_system_seek is null

and U.last_system_scan is null

and U.last_system_lookup is null

order by 1

go

 

-- Return missing indexes

print 'Missing indexes list'

 

select *

from sys.dm_db_missing_index_details

go

 

 
Some frequently asked scripts  
 
 These are some useful scripts, often asked in SQL Server discussion groups.


/*
*********************************************************************
Author      : Bouarroudj Mohamed
E-mail      : mbouarroudj@sqldbtools.com
Date        : 2004
Description : 1. List all tables without primary key
              2. List number of rows in current database
              3. Number of rows and disk space reserved for all tables
              4. Return SQL statement to drop statistic indexes
              5. Find the last restore date for current database
              6. Return the list of job still running
*********************************************************************
*/

-- 1. List all tables without primary key
select ID, user_name(uid) + '.' + name as TableName
from dbo.sysobjects with(nolock)
where type = 'U'
and OBJECTPROPERTY(id, N'TableHasPrimaryKey') = 0
go

-- 2. List number of rows in current database
/*
Notes : 
1. In some cases it is prefered to run DBCC UPDATEUSAGE to correct 
   inaccuracies in the sysindexes table
2. you can also have the same result with : 
   sp_msforeachtable 'select count(*) as '?' from ?'
*/
select T1.ID, user_name(T1.uid) + '.' + T1.name as TableName, T2.rows 
from dbo.sysObjects T1 
join dbo.sysindexes T2 on T1.ID = T2.ID
where T1.Xtype = 'U'
and T2.indid < 2
order by T1.name
go

-- 3. Number of rows and disk space reserved for all tables
sp_msforeachtable 'sp_spaceused ''?''
go

-- 4. Return SQL statement to drop statistic indexes
select 'drop statistics ' + QUOTENAME(user_name(obj.uid)) + '.' + 
       QUOTENAME(obj.name) + '.' + QUOTENAME(ndx.name)
from dbo.sysobjects obj
join dbo.sysindexes ndx on ndx.ID = obj.ID
where obj.xtype in ('U', 'V')   -- user table and view
and   indexproperty(ndx.id, ndx.name, 'IsStatistics') = 1

-- 5. Find the last restore date for current database
select top 1 * 
from msdb.dbo.restorehistory 
where destination_database_name =  db_name()
order by restore_date desc
go

-- 6. Return the list of job still running
exec msdb.dbo.sp_get_composite_job_info @execution_status = 1 --1:Executing

/*
sp_get_composite_job_info parameters :

  @job_id             UNIQUEIDENTIFIER = NULL,
  @job_type           VARCHAR(12)      = NULL,  -- LOCAL or MULTI-SERVER
  @owner_login_name   sysname          = NULL,
  @subsystem          NVARCHAR(40)     = NULL,
  @category_id        INT              = NULL,
  @enabled            TINYINT          = NULL,
  @execution_status   INT              = NULL,
  @date_comparator    CHAR(1)          = NULL,
  @date_created       DATETIME         = NULL,
  @date_last_modified DATETIME         = NULL,
  @description        NVARCHAR(512)    = NULL
*/


 
Kill Processes  
 
 Terminate all processes for specific database.


use master
go

---------------------------------------------------------------------
-- Declarations
---------------------------------------------------------------------

declare
    @Kill     varchar(255),
    @DbName   sysname

---------------------------------------------------------------------
-- Initializations
---------------------------------------------------------------------

set @DbName = 'NorthWind'  -- change the DB name

---------------------------------------------------------------------
-- Processing
---------------------------------------------------------------------

if not exists (select * from master..sysdatabases where name = @DbName)    
begin        
    raiserror('Database does not exists', 16, 1)        
    return 
end

declare #Cur cursor for 
select 'kill '+convert(varchar(5),spid) +' -- '+p.loginame 
from master..sysprocesses p 
inner join master..sysdatabases d on p.dbid = d.dbid 
where d.name = @DbName 

open #Cur
fetch next 
from #Cur into @Kill

while @@fetch_status = 0    
begin        
    exec (@Kill)        

    fetch next from #Cur into @Kill
end

close #Cur 
deallocate #cur
go


 
Blocked Process  
 
 This stored procedure log blocked process in dbo.BlockedProcessTrace user table.


use master
go

if Object_id('dbo.BlockedProcessTrace') is null
begin
    print 'create table dbo.BlockedProcessTrace'
    create table dbo.BlockedProcessTrace
    (
         ID              int identity(1,1) not null, 
         creationdate    datetime, 
         spid            smallint, 
         blocked1        smallint, 
         blocked2        smallint, 
         waittime        int, 
         waittype        binary, 
         lastwaittype    nchar(32),
         waitresource    nchar(256), 
         dbid            smallint, 
         cpu             int, 
         physical_io     bigint, 
         memusage        int,
         cmd             varchar(1000), 
         loginame        nchar(128),
         open_tran       smallint,
         QueryBlocked    varchar(255),
         QueryBlockedBy1 varchar(255),
         QueryBlockedBy2 varchar(255)
    )
end
go

if object_id('dbo.usp_BlockedProcessTrace') is not null
  drop proc dbo.usp_BlockedProcessTrace
go

Create Proc dbo.usp_BlockedProcessTrace
(
    @WaitTimeInSeconde int
)
as 

/*
*********************************************************************
Description : Log blocked processes in dbo.BlockedProcessTrace table
Author      : Bouarroudj Mohamed
E-mail      : mbouarroudj@sqldbtools.com
Date        : November 2004
*********************************************************************
*/

set nocount on

---------------------------------------------------------------------
-- Declarations
---------------------------------------------------------------------

declare 
    @Query           varchar(50),
    @CurrentDate     datetime,
    @QueryBlocked    varchar(255),  -- the Query blocked
    @QueryBlockedBy1 varchar(255),  -- The Query that blocks the 1st one
    @QueryBlockedBy2 varchar(255),  -- The Query that blocks the seconde one
    @spid            smallint, 
    @blocked1        smallint, 
    @blocked2        smallint, 
    @waittime        int, 
    @waittype        binary, 
    @waitresource    nchar(256), 
    @dbid            smallint, 
    @cpu             int, 
    @cmd             varchar(1000), 
    @loginame        nchar(128),
    @open_tran       smallint,
    @lastwaittype    nchar(32), 
    @physical_io     bigint, 
    @memusage        int

---------------------------------------------------------------------
-- Initializations
---------------------------------------------------------------------

set @CurrentDate = GetDate()

create table #dbc
(
    EventType  varchar(15), 
    Parameters int, 
    EventInfo  varchar(255)
)

if @WaitTimeInSeconde is null
    set @WaitTimeInSeconde = 60 * 1000  -- 1 minute 
else
    set @WaitTimeInSeconde = @WaitTimeInSeconde * 1000  -- convert to ms

---------------------------------------------------------------------
-- Processing
---------------------------------------------------------------------

declare processes_cursor cursor fast_forward
for
    select T1.spid, T1.blocked, T1.waittime, T1.waittype, T1.waitresource, 
           T1.dbid, T1.cpu, T1.cmd, T1.loginame, T1.open_tran, T1.lastwaittype, 
           T1.physical_io, T1.memusage, T2.blocked
    from master.dbo.sysprocesses T1 with(nolock) 
    join master.dbo.sysprocesses T2 with(nolock) on T2.spid = t1.blocked
    where T1.blocked <> 0
    and T1.waittime > @WaitTimeInSeconde   

open processes_cursor

fetch next from processes_cursor 
into @spid, @blocked1, @waittime, @waittype, @waitresource, @dbid, @cpu, @cmd, 
     @loginame, @open_tran, @lastwaittype, @physical_io, @memusage, @blocked2
while (@@fetch_status <> -1)
begin   
    delete from #dbc

    set @Query = 'DBCC INPUTBUFFER(' + Cast(@spid as varchar(10)) + ')'
    insert #dbc EXEC(@Query) 
    select @QueryBlocked = EventInfo from #dbc

    set @Query = 'DBCC INPUTBUFFER(' + Cast(@blocked1 as varchar(10)) + ')'
    insert #dbc EXEC(@Query) 
    select @QueryBlockedBy1 = EventInfo from #dbc
 
    if (@blocked2 > 0 and @blocked2 is not null)
    begin
        set @Query = 'DBCC INPUTBUFFER(' + Cast(@blocked2 as varchar(10)) + ')'
        insert #dbc EXEC(@Query) 
        select @QueryBlockedBy2 = EventInfo from #dbc
    end

    insert into dbo.BlockedProcessTrace
    (
      creationdate, 
      spid, 
      blocked1,
      blocked2,
      waittime, 
      waittype, 
      lastwaittype,
      waitresource, 
      dbid, 
      cpu, 
      physical_io, 
      memusage,
      cmd, 
      loginame,
      open_tran,
      QueryBlocked,
      QueryBlockedBy1,
      QueryBlockedBy2
    )

    values
    (
      @CurrentDate,
      @spid, 
      @blocked1,
      @blocked2,
      @waittime,  
      @waittype, 
      @lastwaittype,
      @waitresource, 
      @dbid, 
      @cpu, 
      @physical_io, 
      @memusage,
      @cmd, 
      @loginame,
      @open_tran,
      @QueryBlocked,
      @QueryBlockedBy1,
      @QueryBlockedBy2
    )
       
    fetch next from processes_cursor 
    into @spid, @blocked1, @waittime, @waittype, @waitresource, @dbid, @cpu, @cmd, 
         @loginame, @open_tran, @lastwaittype, @physical_io, @memusage, @blocked2

end

close processes_cursor
deallocate processes_cursor
go

/*

Deployement : We suggest the creation of SQL Job that run every x minutes
Test :

1. Create SQL Job or run the following script

use master 

while 1=1
begin
  exec dbo.usp_BlockedProcessTrace @WaitTimeInSeconde = 1    
  WAITFOR DELAY '00:01:00'
end

2. open new window in Query Analyser and run :

use northwind

begin tran
update dbo.Customers set ContactName = 'M. Maria Anders' where CustomerID = 'ALFKI'
--commit

3. open new window in Query Analyser and run :

use northwind

begin tran
select * from dbo.Customers

4. the process will be blocked and after 1 minute a new entry is created in 
   dbo.BlockedProcessTrace table

select * from master.dbo.BlockedProcessTrace

*/

 
