/**
 *  QuickLiteDatabase.h
 *  A lightweight Cocoa wrapper for SQLite
 *  
 *  Written by Tito Ciuro (21-Jan-2003)

	Copyright (c) 2004, Tito Ciuro
	All rights reserved.

	Redistribution and use in source and binary forms, with or without modification, are permitted
	provided that the following conditions are met:
	
	¥ 	Redistributions of source code must retain the above copyright notice, this list of conditions
		and the following disclaimer.
	¥ 	Redistributions in binary form must reproduce the above copyright notice, this list of conditions
		and the following disclaimer in the documentation and/or other materials provided with the distribution.
	¥ 	Neither the name of Tito Ciuro nor the names of its contributors may be used to endorse or promote
		products derived from this software without specific prior written permission.

	THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED
	WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A
	PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY
	DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
	PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
	CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE
	OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
	SUCH DAMAGE.
*/

#import "sqlite3.h"

#import "QuickLiteGlobals.h"

@class QuickLiteCursor;

@interface QuickLiteDatabase : NSObject
{
    @protected
    sqlite3*                QL_sqliteDatabase;
    NSString*               QL_sqliteDatabasePath;
    QLCacheMethod           QL_cacheMethod;
    NSDictionary*           QL_schema;
    
    int                     QL_lastErrorID;
    NSString*               QL_lastError;
    
    unsigned long           QL_processID;
    NSMutableSet*           QL_modifiedCursors;
    BOOL                    QL_notifySQLStatement;
    BOOL                    QL_isInDebugMode;
    BOOL                    QL_saveChangesWhenClosing;
}

/************************************************************************************

Section:QuickLite

The following section contains methods that allow you manipulate a SQLite
database.

Among other things, these include initializing, opening, closing,
and querying.

***********************************************************************************/

#pragma mark Accessors

+ (id)databaseWithFile:(NSString*)path;
- (id)initWithFile:(NSString*)path;

    /**
    Opening and closing a database previously initialized.
     
     The 'setupQLEnvironment' argument allows you to leave the database 'as is' or to give
     a chance to QuickLite to create its internal tables in order to use QuickEdit.
     
     The 'notifySQL' argument allows QuickLite to include the SQL statement that has caused
     the datatabase to be modified. Although useful to be used together with
     QuickLiteListener.app, you may want to turn it off for deployment. By default, the
     value is NO.
     
     On closing, you can specify whether any unsaved changes should be committed to disk. If
     the database gets deallocated, the database will be closed *without* saving any changes.
     */

    // Opens the database with the following defaults:
    //		setupQLEnvironment = YES
    //		cacheMethod = CacheDataOnDemand
    //		exposeSQLOnNotify = NO
- (BOOL)open;

    // Opens the database with the following defaults:
    //		cacheMethod = CacheDataOnDemand
    //		exposeSQLOnNotify = NO
- (BOOL)open:(BOOL)setupQLEnvironment;

    // Opens the database with the following defaults:
    //		exposeSQLOnNotify = NO
- (BOOL)open:(BOOL)setupQLEnvironment cacheMethod:(QLCacheMethod)cacheMethod;

- (BOOL)open:(BOOL)setupQLEnvironment cacheMethod:(QLCacheMethod)cacheMethod exposeSQLOnNotify:(BOOL)notifySQL debugMode:(BOOL)debug;

    // Close the database. When closing the database, it will save or discard the changes, depending
    // on the settings. See the method 'setSavesChangesWhenClosingDatabase'.
- (BOOL)close;
    // Close the database manually specifying whether the changes should be saved or discarded.
- (BOOL)closeSavingChanges:(BOOL)flag;

    // Specify whether any changes in the database should be saved when closing the
    // database. By default the value is 'YES'.
- (void)setSavesChangesWhenClosingDatabase:(BOOL)flag;
- (BOOL)savesChangesWhenClosingDatabase;

    /**
    Find out whether the database has any unsaved changes.
     */
- (BOOL)hasUnsavedChanges;

    /**
    Attempt to save the database.
     
     If there were no errors found in the transaction, YES is returned. No otherwise.
     */
- (BOOL)save;

    /**
    Revert all changes made to the database which are still uncommited.
     */
- (void)revert;

    /**
    Find out whether the database is currently open
     */
- (BOOL)isDatabaseOpen;

    /**
    Set the path for the current database
     */
- (void)setDatabasePath:(NSString*)path;

    /**
    Retrieve the path for the current database
     */
- (NSString*)databasePath;

    /**
    Find out whether QuickLite fetches data lazily (on demand) or whether it's done
     all at once.
     */
- (QLCacheMethod)cacheMethod;

    /**
    Set the cache method. This setting affects QuickLite immediately. No restart is required.
     */
- (void)setCacheMethod:(QLCacheMethod)cacheMethod;

    /**
    Find out whether QuickLite sends the SQL statement when notifying about database
     changes.
     */
- (BOOL)sendsSQLStatementWhenNotifyingOfChanges;

    /**
    Set whether QuickLite sends the SQL statement when notifying about database changes.
     */
- (void)setSendsSQLStatementWhenNotifyingOfChanges:(BOOL)flag;

    /**
    Set whether we want to log info.
     */
- (void)setIsInDebugMode:(BOOL)flag;

    /**
    Find out whether QuickLite prints out the names of the methods as it's calling them.
     */
- (BOOL)isInDebugMode;

    /**
    Check whether there is an active transaction.
     */
- (BOOL)isTransactionActive;

    /**
    Imports data from a text file.
     Requirements:
     
     - The filePath must exist
     - Both delimiterCode and endOfRecordCode must be valid ASCII codes
     - When a file import is requested, QuickLite expects the table to be defined in the data base. If the table does not exist, the import operation will fail. If you use dropTableIfItExistsAndRecreate = NO, you must ensure that: 1) the table already exists in the database and 2) that the columns referenced in the import file have been defined for that table. Otherwise, either QLImportFileTableNotFound or QLImportColumnsNonConforming will be returned, depending on what causes the fault.
     
     Modus Operandi:
     
     - If the 'table' var is a non-empty string, QuickLite will use that value to name the table and the first row found on the import file as a source of information to name the columns. For example:
     
     [myDatabase importFromFile:@"~/toto.txt" encoding:NSMacOSRomanStringEncoding columnDelimiter:1 endOfRecord:13 table:@"people" dropTableIfItExistsAndRecreate:YES clearTableContentsBeforeImporting:YES]
     
     The import file "toto.txt" contains the following data:
     
     first		phone
     *******            *****
     tito		12345
     cricket		34521
     brett		45456
     
     - If dropTableIfItExistsAndRecreate is set to YES, QuickLite will drop the table (if it exists) and create it with the name passed in the 'table' var, and the column names will be obtained from the first imported row.
     
     - If clearTableContentsBeforeImporting is set to YES, the contents of the table will be clared prior to the import.
     
     - If at some point the end-of-file is reached or a line is found with a non-conforming(*) number of columns, the import process will finish immediately. All records imported up to this point will be honored and saved.
     
     (*) If a row contains a number of values which does not match the number of columns, it is said to be non-conforming. In the example above, there are three columns:first and phone. All records must include a value for each of the columns. If no value exists, an empty string (@"") must be used instead.
     */

#pragma mark Import data
- (QLImportResult)importFromFile:(NSString*)filePath encoding:(NSStringEncoding)encoding columnDelimiter:(NSString*)colDelim endOfRecord:(NSString*)eolDelim table:(NSString*)table dropTableIfItExistsAndRecreate:(BOOL)dropAndRecreateTableFlag clearTableContentsBeforeImporting:(BOOL)clearTableFlag;

    /**
    Compacts the data file
     
     When information is deleted in the database, and a btree page becomes empty, it isn't removed from the database file,
     but is instead marked as 'free' for future use. When a new page is needed, SQLite will use one of these free pages before
     increasing the database size. This results in database fragmentation, where the file size increases beyond the size required
     to store its data, and the data itself becomes disordered in the file.
     
     Another side effect of a dynamic database is table fragmentation. The pages containing the data of an individual table can become
     spread over the database file, requiring longer for it to load. This can appreciably slow database speed because of file system
     behavior. Compacting fixes both of these problems.
     */

#pragma mark Utilities

    /**
    Properly escapes queries containing single quotes.
     This method is a convenience methods which calls 'prepareStringForQuery'.
     Example:
     Original query:SELECT last FROM address WHERE last = O'Reilly
     After calling escapeQuotesFromString we have:SELECT last FROM address WHERE last = O''Reilly
     */
+ (NSString*)escapeQuotesFromString:(NSString*)string;

+ (NSString *)UUIDString;

- (BOOL)compact;

- (BOOL)integrityCheck;

- (NSString*)sqliteVersion;

- (NSString*)databaseEncoding;

#pragma mark Executing SQL statements

    /**
    Properly escapes queries containing single quotes.
     Example:
     Original query:SELECT last FROM address WHERE last = O'Reilly
     After calling prepareStringForQuery:SELECT last FROM address WHERE last = O''Reilly
     */
+ (NSString*)prepareStringForQuery:(NSString*)string;

    /**
    Execute a SQL query. The first method acknowledges the cache method set when the
     database was opened. The second method allows you to set the cache for this particular
     cursor. If the query is not a PRAGMA or SELECT type of query, cacheMethod is ignored.
     */
- (QuickLiteCursor*)performQuery:(NSString*)sqlQuery;
- (QuickLiteCursor*)performQuery:(NSString*)sqlQuery cacheMethod:(QLCacheMethod)cacheMethod;

    /************************************************************************************

                         Section:Introspection

    The following section contains methods that allow obtain information about
    a database.

    This information includes names of the tables, its columns and indexes. The
    same information can be obtained on temporary tables, its columns and indexes.

    ***********************************************************************************/

#pragma mark Introspection methods

    /**
    Obtains all user-defined tables in the database
     */
- (NSArray*)tables;

    /**
    Obtains all tables per available database, including QuickLite's
     */
- (NSDictionary*)allTables;

    /**
    Obtains all columns for a given table.
     */
- (NSArray*)columnsForTable:(NSString*)table;

    /**
    Obtains all indexes for a given table
     */
- (NSArray*)indexedColumnsForTable:(NSString*)table;

    /**
    Obtains all data types for a given table
     */
- (NSArray*)datatypesForTable:(NSString*)table;

    /**
    Obtains all temporary tables in the database
     */
- (NSArray*)temporaryTables;

    /**
    Obtains the latest rowUID added to the database by SQLite
     
     Please make sure that you've created the table with one column declared as
     INTEGER PRIMARY KEY, otherwise this method will not work.
     */
- (NSNumber*)lastRowInserted;

    /**
    Obtains the largest rowUID for a given table.
     
     This call issues a SQL statement in the form: SELECT max(ROWID) FROM mytable.
     */
- (unsigned long)maxRowUIDForTable:(NSString*)table;

    /**
    Returns the last error ID as reported by SQLite.
     */
- (int)lastErrorID;

    /**
    Returns the last error string as reported by SQLite.
     */
- (NSString*)lastError;

- (NSString*)descriptionForValue:(id)value;

    /************************************************************************************

    Section:SQLite tunning

    The following section contains methods that allow fine-tune SQLite to your
    liking.

    This information includes names of the tables, its columns and indexes. The
    same information can be obtained on temporary tables, its columns and indexes.

    ***********************************************************************************/

#pragma mark Customizing SQLite

    /**
    Set the amount of time in milliseconds that SQLite will wait before returning SQLITE_BUSY.
     
     Very important if you are going to access the same database from multiple apps; otherwise queries
     will fail if another process is in the middle of a transaction.
     */
- (void)setBusyTimeout:(unsigned int)msTimeout;

    /**
    Query or change the maximum number of database disk pages that SQLite will hold in memory at once.
     Each page uses about 4KB of memory. The default cache size is 2000.  If you are doing UPDATEs or
     DELETEs that change many rows of a database and you do not mind if SQLite uses more memory, you can
     increase the cache size for a possible speed improvement.
     */
- (unsigned int)sessionCacheSize;
- (void)setSessionCacheSize:(unsigned int)numberOfPages;

    /**
    Query or change the setting of the "synchronous" flag in the database.
     
     When synchronous mode is FULL, the SQLite database engine will pause at critical moments to make sure
     that data has actually been written to the disk surface before continuing. This ensures that if the
     operating system crashes or if there is a power failure, the database will be uncorrupted after
     rebooting. FULL synchronous is very safe, but it is also slow.
     
     When synchronous is NORMAL, the SQLite database engine will still pause at the most critical moments,
     but less often than in FULL mode. There is a very small (though non-zero) chance that a power failure
     at just the wrong time could corrupt the database in NORMAL mode. But in practice, you are more likely
     to suffer a catastrophic disk failure or some other unrecoverable hardware fault. So NORMAL is the
     default mode.
     
     With synchronous OFF, SQLite continues without pausing as soon as it has handed data off to the
     operating system. If the application running SQLite crashes, the data will be safe, but the database
     might become corrupted if the operating system crashes or the computer loses power before that data
     has been written to the disk surface. On the other hand, some operations are as much as 50 or more
     times faster with synchronous OFF.
     */
- (QLSynchronousMode)synchronousMode;
- (void)setSynchronousMode:(QLSynchronousMode)mode;

    /**
    Query or change the setting of the "temp_store" flag affecting the database for the duration of the
     current database connection. The temp_store flag reverts to its default value when the database is
     closed and reopened.
     
     When temp_store is DEFAULT, the compile-time default is used for the temporary database.
     
     When temp_store is FILE, a temporary database file on disk will be used.  Note that it is possible
     for the library compile-time options to override this setting.
     
     When temp_store is MEMORY, an in-memory database is used.
     
     <b>*** Important ***</b><br>
     <b>Once the temporary database is in use, its location cannot be changed. This is a SQLite limitation.</b>
     */
- (QLTempStoreMode)tempStoreMode;
- (void)setTempStoreMode:(QLTempStoreMode)mode;

#pragma mark Encoding binary data

    /**  Encode binary data to be stored via QuickLite

    If you need to decode back from QuickLite, do that from the row object. Instead of
    retrieving the data via valueForColumn:which will return a NSString, you can do it via dataForColumn:
    and it'll return a NSData.

    For more info, see the BLOBTester example.
    */
- (NSString*)encodeDataToBase64:(NSData*)data;
- (NSData*)decodeDataFromBase64:(NSString*)encodedData;

@end