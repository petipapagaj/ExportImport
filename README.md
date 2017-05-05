# ExportImport

# What is Export Import data utility?
Exporting data from one database and import to another is no longer painfully. Calling simply the tool is generating the insert statements which you can use in another database to be execute. 

# Export
Utility is uploaded to the repository and ready to use above bold version 10.5

``` 
DECLARE @ret INT
EXEC @ret = Utilities.ExportData
@AccountID = 0, -- bigint
@Prefix = NULL, -- varchar(max)
@Exception = NULL, -- varchar(max)
@Top = NULL, -- int
@NoResult = NULL, -- bit
@Filter = NULL -- varchar(max)
SELECT @ret
``` 

## Parameter description
* @AccountID (bigint, not null): Data is exported which belong to the specified account. AccountID is required.
* @Prefix (varchar(max), null): Data is exported only from the tables which the mask is matching to. E.g: the following parameter values will dump out only the records from bc_* and lc_* tables: @Prefix = 'bc_,lc_'
* @Exception (varchar(max), null): Export tool will skip the tables you specify by the @Exception parameter
* @Top (int, 1000): Exporting only the top x rows from every table. By default it is set to 1000
* @NoResult (bit, 0): Specifying 1 for @NoResult parameter will producing no rows as return, though it can be selecting from tempdb.dbo.boldcenterData
* @Filter (varchar(max), null): Exporting data only from the specified tables, e.g: @Filter = 'bc_Folders,lc_Chats'

# Import
Due to the huge data might be in the database the import tool is working as a batch processed insert execution.
``` 
EXEC Utilities.ImportData
``` 
