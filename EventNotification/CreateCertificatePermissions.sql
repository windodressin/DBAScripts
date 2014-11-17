
-- Security setup
use DBA_STORE
go

create master key encryption 
by password = 'whitehouse'
go

create certificate EventMonitoringCert 
with subject = 'Cert for event monitoring', 
expiry_date = '20201031';
go

-- We need to re-sign every time we alter 
-- the stored procedure
add signature to dbo.usp_CaptureBlockingEvents
by certificate EventMonitoringCert
GO

backup certificate EventMonitoringCert
to file='EventMonitoringCert.cer'
go

use master
go

create certificate EventMonitoringCert
from file='EventMonitoringCert.cer'
go


create login EventMonitoringLogin
from certificate EventMonitoringCert
go

grant view server state, 
	authenticate server to EventMonitoringLogin
go
