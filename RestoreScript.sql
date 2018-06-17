/*
sp_helpfile 

--maxdev
maxdev	1	E:\DBdata\maxdev.mdf
maxdev_log	2	D:\DBlog\maxdev_log.ldf
maxdev2	3	D:\DBdata\maxdev2.ndf

--maxtest
maxdev	1	D:\DBData\maxtest.mdf
maxdev_log	2	E:\DBData\maxtest_log.ldf
maxdev2	3	E:\DBData\maxtest2.ndf

*/


--backup database maxdev to disk = 'd:\backup\maxdev_20180514.bak' with compression


/*
restore database maxtest from disk = 'd:\backup\maxdev_20180514.bak' with 
move 'maxdev' to 'D:\DBData\maxtest\maxtest.mdf',
move 'maxdev_log' to 'E:\DBData\maxtest\maxtest_log.ldf',
move 'maxdev2' to 'E:\DBData\maxtest\maxtest2.ndf',
recovery, stats, replace
*/

--select 'sp_dropuser ' +'[' +  name + ']' + ' GO ' from sysusers where name not in ('CALPINENA\vc12035','CALPINENA\georges', 'CALPINENA\kw14500')

/*
--Get orphaned users
SELECT dp.type_desc, dp.SID, dp.name AS user_name  
FROM sys.database_principals AS dp  
LEFT JOIN sys.server_principals AS sp  
    ON dp.SID = sp.SID  
WHERE sp.SID IS NULL  
    AND authentication_type_desc = 'INSTANCE';  


--Map user with existing login
ALTER USER <user_name> WITH Login = <login_name>;  
*/