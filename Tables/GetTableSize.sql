--Get Table Size

DECLARE @TableName VARCHAR(200)

-- Insert statements for procedure here
DECLARE tableCursor CURSOR FOR
SELECT sys.schemas.[name]+'.['+sys.objects.[name] + ']'
FROM sys.schemas INNER JOIN sys.objects ON sys.schemas.schema_id=sys.objects.schema_id
WHERE type='U' AND is_ms_shipped=0 ORDER BY sys.schemas.[name] -- WHERE is_ms_shipped is Microsoft generated objects
FOR READ ONLY
--A procedure level temp table to store the results
CREATE TABLE #TempTable
(
tableName varchar(200),
numberofRows varchar(100),
reservedSize varchar(50),
dataSize varchar(50),
indexSize varchar(50),
unusedSize varchar(50)
)

--Open the cursor
OPEN tableCursor

--Get the first Record from the cursor
FETCH NEXT FROM tableCursor INTO @TableName

--Loop until the cursor was not able to fetch
WHILE (@@Fetch_Status >= 0)
BEGIN
--Insert the results of the sp_spaceused query to the temp table
INSERT #TempTable
EXEC sp_spaceused @TableName

--Get the next Record
FETCH NEXT FROM tableCursor INTO @TableName
END

--Close/Deallocate the cursor
CLOSE tableCursor
DEALLOCATE tableCursor

--Select all records so we can use the reults
update #TempTable
set reservedSize = REPLACE(reservedSize,'KB','')

SELECT tableName,numberofRows,
(Convert(decimal(6,3),CONVERT(float,REPLACE(reservedSize,'KB','')) /1048576) ) as ReservedsizeGB,
(Convert(decimal(6,3),CONVERT(float,REPLACE(dataSize,'KB','')) /1048576) ) as dataSizeGB,
(Convert(decimal(6,3),CONVERT(float,REPLACE(indexSize,'KB','')) /1048576) ) as indexSizeGB,
(Convert(decimal(6,3),CONVERT(float,REPLACE(unusedSize,'KB','')) /1048576) ) as unusedSizeGB
FROM #TempTable
--where tableName like 'temp%'
order by Convert(decimal(6,3),CONVERT(float,ReservedSize) / 1048576)  desc

DROP TABLE #TempTable

END
