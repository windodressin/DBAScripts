select o.name as TableName,
i.name as IndexName,
(
	SELECT c.name + ', ' 
	FROM sys.index_columns ic 
	JOIN sys.columns c ON ic.column_id = c.column_id and ic.object_id = c.object_id
	WHERE i.object_id = ic.object_id and i.index_id = ic.index_id
	  AND ic.is_included_column = 0
	ORDER BY ic.index_column_id
	FOR XML PATH('')
) AS Key_Columns,
(
	SELECT c.name + ', ' 
	FROM sys.index_columns ic 
	JOIN sys.columns c ON ic.column_id = c.column_id and ic.object_id = c.object_id
	WHERE i.object_id = ic.object_id and i.index_id = ic.index_id
	  AND ic.is_included_column = 1
	ORDER BY ic.index_column_id
	FOR XML PATH('')
) AS IncludedColumns,
i.type_desc as IndexType,
i.is_unique as IsUnique,
i.is_primary_key as IsPrimaryKey
from sys.indexes i
join sys.objects o on i.object_id = o.object_id
where o.is_ms_shipped = 0 and i.name = 'IDF_VinDID_tblEvents'

SELECT NINE.TABLENAME, NINE.INDEXNAME, NINE.KEY_COLUMNS, TEN.TABLENAME, TEN.INDEXNAME, TEN.KEY_COLUMNS  FROM ##CAR9 NINE LEFT JOIN ##CAR10 TEN ON NINE.TABLENAME = TEN.TABLENAME 
select * from sysindexes
USE CAR9
GO
SELECT NINE.TABLENAME AS CAR9_TABLENAME, NINE.INDEXNAME, NINE.KEY_COLUMNS  FROM ##CAR9 NINE WHERE NINE.INDEXNAME = 'IDF_VinDID_tblEvents'
EXCEPT SELECT TEN.TABLENAME, TEN.INDEXNAME, TEN.KEY_COLUMNS FROM ##CAR10 TEN 

USE CAR10
GO
SELECT TEN.TABLENAME AS CAR10_TABLENAME, TEN.INDEXNAME, TEN.KEY_COLUMNS  FROM ##CAR10 TEN WHERE TEN.INDEXNAME = 'nc_ronum'
EXCEPT SELECT NINE.TABLENAME, NINE.INDEXNAME, NINE.KEY_COLUMNS FROM ##CAR9 NINE