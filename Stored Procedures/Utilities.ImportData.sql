SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO


CREATE PROCEDURE [Utilities].[ImportData]

AS

SET NOCOUNT ON

IF OBJECT_ID('tempdb.dbo.boldcenterData') IS NULL
	RETURN 1 --no data to import

DECLARE @xml XML
DECLARE @Data NVARCHAR(MAX)
DECLARE @pending TABLE (ID INT, Data NVARCHAR(MAX))
DECLARE @batch INT = 10 --should be more intelligent based on bytes
DECLARE @checkpoint INT = 0
DECLARE @rowcount INT = NULL 

WHILE 1 = 1
BEGIN
	WAITFOR DELAY '000:00:01.000'

	INSERT INTO @pending ( ID, Data ) 
	SELECT TOP (@batch) ID, Data 
	FROM tempdb.dbo.boldcenterData
	WHERE ID > @checkpoint
	ORDER BY ID ASC

	SET @rowcount = @@ROWCOUNT

	SET @xml = (
	SELECT ''+ CHAR(13)+CHAR(10) + Data
	FROM @pending AS p
	FOR XML PATH ('')
	)


	SELECT @Data = REPLACE(REPLACE(CONVERT(VARCHAR(MAX), @xml), '&#x0D;', ''), '&amp;', '&')
	EXEC (@data)

	SELECT @checkpoint = MAX(ID) FROM @pending AS p

	--PRINT @checkpoint

	DELETE FROM @pending


	IF @rowcount < @batch
		BREAK


END 

RETURN 0
GO
