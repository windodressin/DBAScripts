USE MSDB
GO
SELECT sa.account_id,
spa.profile_id,
sa.name,
sa.email_address,
sa.display_name, 
sp.name AS profile_name 
FROM 
sysmail_profile sp JOIN sysmail_profileaccount spa ON sp.profile_id = spa.profile_id 
JOIN sysmail_account sa ON spa.account_id = sa.account_id

--select * from sysmail_profile