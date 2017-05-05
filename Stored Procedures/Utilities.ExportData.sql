SET QUOTED_IDENTIFIER OFF
GO
SET ANSI_NULLS ON
GO

CREATE PROCEDURE [Utilities].[ExportData]
    @AccountID BIGINT,
	@Prefix VARCHAR(MAX) = NULL,
	@Exception VARCHAR(MAX) = NULL,
	@Top INT = 1000,
	@NoResult BIT = 0,
	@Filter VARCHAR(MAX) = NULL
AS

SET NOCOUNT ON

DECLARE @table VARCHAR(128)
DECLARE @core VARCHAR(max)
DECLARE @data TABLE (Tab VARCHAR(128), PK VARCHAR(128), Data NVARCHAR(max))
DECLARE @conversions TABLE (DataType VARCHAR(128), Characters int)
DECLARE @LocalTop VARCHAR(10) 
DECLARE @Prefixes dbo.VC128
DECLARE @Filters dbo.VC128
DECLARE @Exceptions dbo.VC128

IF @Prefix IS NOT NULL
	INSERT INTO @Prefixes ( String ) SELECT uss.String FROM dbo.udfSplitString(@Prefix, ',') AS uss

IF @Filter IS NOT NULL
	INSERT INTO @Filters ( String ) SELECT uss.String FROM dbo.udfSplitString(@Filter, ',') AS uss

IF @Exception IS NOT NULL
	INSERT INTO @Exceptions ( String ) SELECT uss.String FROM dbo.udfSplitString(@Exception, ',') AS uss

IF @Top IS NOT NULL
	SET @LocalTop = CONVERT(VARCHAR(10), @Top)	

IF OBJECT_ID('tempdb.dbo.boldcenterData') IS NOT NULL 
	DROP TABLE tempdb.dbo.boldcenterData

CREATE TABLE tempdb.dbo.boldcenterData (ID INT IDENTITY(1,1),Tab VARCHAR(128), Data NVARCHAR(MAX), Size BIGINT) --support batch execution 
    

INSERT INTO @conversions ( DataType, Characters )
VALUES  ( 'bigint', 25),
		( 'int', 15),
		( 'float', 12),
		( 'decimal', 32),
		('uniqueidentifier', 64),
		( 'tinyint', 6),
		( 'datetime', 19),
		( 'bit', 1),
		( 'smallint', 10),
		( 'char', 10)



DECLARE tableCursor CURSOR FAST_FORWARD READ_ONLY

FOR
    SELECT DISTINCT t.TABLE_NAME
    FROM INFORMATION_SCHEMA.TABLES AS t
	INNER JOIN INFORMATION_SCHEMA.COLUMNS AS c ON c.TABLE_NAME = t.TABLE_NAME AND c.TABLE_SCHEMA = t.TABLE_SCHEMA
    WHERE t.TABLE_SCHEMA = 'dbo' AND t.TABLE_TYPE = 'BASE TABLE' AND t.TABLE_NAME NOT LIKE '%deleted%' AND c.COLUMN_NAME = 'AccountID'
		AND ((@Prefix IS NULL OR @Prefix = '') OR EXISTS (SELECT 1 FROM @Prefixes AS p WHERE t.TABLE_NAME LIKE p.String + '%' ))
		AND ((@Filter IS NULL OR @Filter = '') OR EXISTS (SELECT 1 FROM @Filters AS f WHERE t.TABLE_NAME = f.String ))
		AND t.TABLE_NAME NOT IN (SELECT e.String FROM @Exceptions AS e)
	ORDER BY t.TABLE_NAME

OPEN tableCursor;

FETCH NEXT FROM tableCursor INTO @table;

WHILE @@FETCH_STATUS = 0
    BEGIN

		SELECT @core = 
	     "SELECT TOP (  "+ @LocalTop + " ) '" + @table + "' as tab,"+ ISNULL(Col.COLUMN_NAME, 'NULL') +" as PK, '"
		+ "INSERT INTO dbo."+ @table +
		 " ( "+

			STUFF((SELECT ',' + c.COLUMN_NAME 
					  FROM INFORMATION_SCHEMA.COLUMNS AS c 
					  WHERE t.TABLE_NAME = c.TABLE_NAME 
						AND NOT EXISTS (SELECT 1 
										FROM sys.syscolumns AS s 
										INNER JOIN sys.tables AS t ON s.id = t.object_id
										WHERE s.iscomputed = 1 AND s.name = c.COLUMN_NAME AND t.name = c.TABLE_NAME)
					  FOR XML PATH('')), 1, 1, '') + " )" +
		 
		 " VALUES ('"+ 
			STUFF((SELECT ' + '' '''',''''''+' 
						+ CASE 
							WHEN c.DATA_TYPE IN ('varchar', 'nvarchar' )
								THEN " CAST(ISNULL( REPLACE("+ c.COLUMN_NAME + ",'''',''''''),'NULL') AS "+ c.DATA_TYPE +" ( "+ REPLACE(CAST(c.CHARACTER_MAXIMUM_LENGTH AS VARCHAR(50)), '-1','max') +" ) )" 
							WHEN c.DATA_TYPE = "varbinary"
								THEN " 'CONVERT(VARBINARY(max),''' + ISNULL(CONVERT(VARCHAR(MAX), [" + c.COLUMN_NAME + '], 2) ,"NULL")  ' + "+ ''' ,2)'"
							ELSE "ISNULL(CONVERT ( VARCHAR("+(SELECT DISTINCT CONVERT(VARCHAR(4),cv.Characters) FROM @conversions AS cv WHERE c.DATA_TYPE = cv.DataType)+"),  [" + c.COLUMN_NAME + "] ),'NULL')"  END
					  FROM INFORMATION_SCHEMA.COLUMNS AS c 
					  WHERE t.TABLE_NAME = c.TABLE_NAME 
						AND NOT EXISTS (SELECT 1 
										FROM sys.syscolumns AS s 
										INNER JOIN sys.tables AS t ON s.id = t.object_id
										WHERE s.iscomputed = 1 AND s.name = c.COLUMN_NAME AND t.name = c.TABLE_NAME)
					  FOR XML PATH('')), 1, 9, '') 
			 + " + ''') ' + CHAR(13)+CHAR(10) + ' " 
		+ " '  AS ColHash FROM dbo." + t.TABLE_NAME + " WHERE AccountID = " + CAST(@AccountID AS VARCHAR(19)) 
			   
		FROM INFORMATION_SCHEMA.TABLES AS t
		LEFT JOIN INFORMATION_SCHEMA.TABLE_CONSTRAINTS Tab ON Tab.TABLE_NAME = t.TABLE_NAME AND Tab.TABLE_SCHEMA = t.TABLE_SCHEMA
		LEFT JOIN INFORMATION_SCHEMA.CONSTRAINT_COLUMN_USAGE Col ON Col.CONSTRAINT_NAME = Tab.CONSTRAINT_NAME AND Col.TABLE_NAME = Tab.TABLE_NAME 
		WHERE t.TABLE_NAME = @table AND t.TABLE_SCHEMA = 'dbo'

		--print @core

		IF @core  <> '' AND @core IS NOT NULL

			INSERT @data (Tab, PK, Data )
			EXEC (@core)


        FETCH NEXT FROM tableCursor INTO @table
    END;

CLOSE tableCursor
DEALLOCATE tableCursor


INSERT INTO tempdb.dbo.boldcenterData ( Tab, Data, Size )
SELECT h.Tab , REPLACE(REPLACE(REPLACE(REPLACE(h.Data, "'NULL'", "NULL"), "'NULL '", "NULL" ), "'CONVERT(VARBINARY(max),", "CONVERT(VARBINARY(max),"), ",2) '", ",2)") AS Data, DATALENGTH(h.Data) FROM @data AS h


IF @NoResult = 0
	SELECT * FROM tempdb.dbo.boldcenterData AS bd


RETURN 0



GO
