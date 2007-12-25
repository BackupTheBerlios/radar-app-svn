/*
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
 
#import "QuickLiteDatabase.h"
#import "QuickLiteDatabasePrivate.h"
#import "QuickLiteGlobals.h"
#import "QuickLiteCursor.h"
#import "QuickLiteCursorPrivate.h"
#import "QuickLiteRowPrivate.h"
#import "QuickLiteDatabaseExtras.h"

#import "sqliteInt.h"
#import <stdio.h>
#import <stdlib.h>

#pragma mark// ==================================
#pragma mark// QuickLiteDatabase C Declarations
#pragma mark// ==================================

/*
 Base64 Encoding
 */
static char base64Table[] = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";

#pragma mark -

@implementation QuickLiteDatabase

/*" QuickLiteDatabase is a wrapper for a SQLite database. "*/

#pragma mark -

#pragma mark// ==================================
#pragma mark// Initialization/Cleanup Methods
#pragma mark// ==================================

/*" Create an instance of a QuickLiteDatabase by passing a full path. "*/

+ (id)databaseWithFile:(NSString*)path
{
    return [[[self alloc] initWithFile:path]autorelease];
}

- (id)initWithFile:(NSString*)path
{
    if( ![self init] )
        return nil;
    
    [self setDatabasePath:[[path stringByExpandingTildeInPath]copy]];
    
    return self;
}

- (id)init
{
    [self setDatabasePath:nil];
    
    QL_schema = nil;
    QL_modifiedCursors = nil;
    
    [self setSendsSQLStatementWhenNotifyingOfChanges:NO];
    [self setIsInDebugMode:NO];
    
    return self;
}

- (void)dealloc
{
    [QL_schema release];
    QL_schema = nil;
    
    [self close];
    
    [super dealloc];
}

#pragma mark// ==================================
#pragma mark// Opening & Closing Methods
#pragma mark// ==================================

- (BOOL)open
{
    return [self open:YES cacheMethod:CacheDataOnDemand exposeSQLOnNotify:NO debugMode:NO];
}

- (BOOL)open:(BOOL)setupQLEnvironment
{
    return [self open:setupQLEnvironment cacheMethod:CacheDataOnDemand exposeSQLOnNotify:NO debugMode:NO];
}

- (BOOL)open:(BOOL)setupQLEnvironment cacheMethod:(QLCacheMethod)cacheMethod
{
    return [self open:setupQLEnvironment cacheMethod:cacheMethod exposeSQLOnNotify:NO debugMode:NO];
}

- (BOOL)open:(BOOL)setupQLEnvironment cacheMethod:(QLCacheMethod)cacheMethod exposeSQLOnNotify:(BOOL)notifySQL debugMode:(BOOL)debug
{
    // Do not log info
    [self setIsInDebugMode:debug];
    
    // Log info if required...
    [self QLP_logIfInDebugMode:_cmd forClass:[self class]];
    
    int err = sqlite3_open( [QL_sqliteDatabasePath fileSystemRepresentation], &QL_sqliteDatabase);
    
    if (err != QLSuccess) {
        [self QLP_setLastError: sqlite3_errmsg([self QLP_sqliteDatabase]) withID: err];
        return NO;
    }
    
    // Start listening to distributed QL_PrivateNotificationSchemaHasChanged and QL_PrivateNotificationContentsHaveChanged messages
    NSDistributedNotificationCenter* center = [NSDistributedNotificationCenter defaultCenter];
    [center addObserver:self selector:@selector(_communicateDatabaseHasChanged:) name:QLP_QuickLiteDatabaseDidChangeNotification object:nil];
    [center addObserver:self selector:@selector(_communicateCompactingDoneChanged:) name:QLP_QuickLiteDatabaseDidCompactNotification object:nil];
    
    // Save whether we want data to be fetched lazily
    QL_cacheMethod = cacheMethod;
    
    // Set whether we're sending SQL statements upon notify
    [self setSendsSQLStatementWhenNotifyingOfChanges:notifySQL];
    
    if (setupQLEnvironment) {
        // Make sure we have QLP_SchemaTable in place. Create it *only* if it's a new database.
        NSArray* tables = [self QLP_flattenAllTables];
        if (([tables count] == 0) && (![tables containsObject:QLP_SchemaTable])) {
            // Add the QLP_SchemaTable table
            NSArray* columns = [[NSArray alloc]initWithObjects:QLP_TableIdentifier, QLP_ColumnIdentifier, QLP_DatatypeIdentifier, nil];
            NSArray* datatypes = [[NSArray alloc]initWithObjects:QLString, QLString, QLString, nil];
            
            [self createTable:QLP_SchemaTable withColumns:columns andDatatypes:datatypes];
            
            // Cleanup
            [columns release];
            [datatypes release];
            
            if ([self lastErrorID] != QLSuccess) {
                NSLog(@"Error opening the database:could not create the table 'QLP_SchemaTable'. %@ (%d)", [self lastError], [self lastErrorID]);
                return NO;
            }
        }
    }
    
    // Initialize the 'save changes' flag
    [self setSavesChangesWhenClosingDatabase:YES];
    
    // Initialize the error manager
    [self QLP_setLastError:NULL withID:QLSuccess];
    
    // Save our process ID
    QL_processID = (pid_t)[[NSProcessInfo processInfo] processIdentifier];
    
    // Refresh the schema cache
    [self QLP_rebuildDatatypeCache];
    
    [self QLP_installCommitCallback];
    
    return YES;
}

- (BOOL)close
{
    return [self closeSavingChanges:[self savesChangesWhenClosingDatabase]];
}

- (BOOL)closeSavingChanges:(BOOL)flag
{
    // Log info if required...
    [self QLP_logIfInDebugMode:_cmd forClass:[self class]];
    
    if(![self QLP_sqliteDatabase])
        return NO;
    
    NSDistributedNotificationCenter* distributedCenter = [NSDistributedNotificationCenter defaultCenter];
    [distributedCenter removeObserver:self name:QLP_QuickLiteDatabaseDidChangeNotification object:nil];
    [distributedCenter removeObserver:self name:QLP_QuickLiteDatabaseDidCompactNotification object:nil];
    
    if (flag) {
        [self save];
    } else {
        if ([self isTransactionActive])
            [self rollbackTransaction];
    }
    
    // Make sure we clear the temporary data from QL_schema
    [self beginTransaction];
    NSArray* tempTables = [self temporaryTables];
    int i, tableCount = [tempTables count];
    
    for (i = 0; i < tableCount; i++) {
        NSString* table = [tempTables objectAtIndex:i];
        [self dropTable:table];
    }
    [self commitTransaction];
    
    int err = sqlite3_close([self QLP_sqliteDatabase]);
    [self QLP_setLastError: sqlite3_errmsg([self QLP_sqliteDatabase]) withID: err];
    
    QL_sqliteDatabase = NULL;
    
    // Tell our cursors we're no longer valid because we're closing the shop...
    NSNotificationCenter* center = [NSNotificationCenter defaultCenter];
    [center postNotificationName:QLP_QuickLiteDatabaseDidCloseNotification object:self];
    
    [QL_modifiedCursors release];
    QL_modifiedCursors = nil;
    
    [self setDatabasePath:nil];
    
    return (err == QLSuccess);
}

- (void)setSavesChangesWhenClosingDatabase:(BOOL)flag
{
    QL_saveChangesWhenClosing = flag;
}

- (BOOL)savesChangesWhenClosingDatabase
{
    return QL_saveChangesWhenClosing;
}

- (BOOL)hasUnsavedChanges
{
    return ([QL_modifiedCursors count] > 0);
}

- (BOOL)save
{
    // Log info if required...
    [self QLP_logIfInDebugMode:_cmd forClass:[self class]];
    
    if (![self isDatabaseOpen]) {
        [self QLP_setLastError:"The database is closed." withID:QLP_UnknownError];
        return NO;
    }
    
    if (![self hasUnsavedChanges]) {
        [self QLP_setLastError:"The database doesn't have unsaved changes." withID:QLP_UnknownError];
        return NO;
    }
    
    BOOL isTransactionOK = YES;	
    NSEnumerator* enumerator = [QL_modifiedCursors objectEnumerator];
    QuickLiteCursor* cursor;
    
    [self beginTransaction];
    
    while (cursor = [enumerator nextObject]) {
        if (![cursor QLP_saveAndDeregisterCursor:NO])
            isTransactionOK = NO;
    }
    
    // Cleanup if needed...
    if (isTransactionOK) {
        [self commitTransaction];
        
        [QL_modifiedCursors removeAllObjects];
    } else {
        [self rollbackTransaction];
    }
    
    return isTransactionOK;
}

- (void)revert
{
    // Log info if required...
    [self QLP_logIfInDebugMode:_cmd forClass:[self class]];
    
    NSEnumerator* enumerator = [QL_modifiedCursors objectEnumerator];
    QuickLiteCursor* cursor;
    
    while ((cursor = [enumerator nextObject])) {
        [cursor QLP_revertAndDeregisterCursor:NO];
    }
    
    [self rollbackTransaction];
    
    // Cleanup...
    [QL_modifiedCursors removeAllObjects];
}

- (BOOL)isDatabaseOpen
{
    return ([self QLP_sqliteDatabase] != NULL);
}

- (void)setDatabasePath:(NSString*)path
{
    if (path != QL_sqliteDatabasePath) {
        [path retain];
        [QL_sqliteDatabasePath release];
        QL_sqliteDatabasePath = path;
    }
}

- (NSString*)databasePath
{
    return [[QL_sqliteDatabasePath copy]autorelease];
}

- (QLCacheMethod)cacheMethod
{
    return QL_cacheMethod;
}

- (void)setCacheMethod:(QLCacheMethod)cacheMethod
{
    QL_cacheMethod = cacheMethod;
}

- (BOOL)sendsSQLStatementWhenNotifyingOfChanges
{
    return QL_notifySQLStatement;
}

- (void)setSendsSQLStatementWhenNotifyingOfChanges:(BOOL)flag
{
    QL_notifySQLStatement = flag;
}

- (void)setIsInDebugMode:(BOOL)flag
{
    QL_isInDebugMode = flag;
}

- (BOOL)isInDebugMode
{
    return QL_isInDebugMode;
}

- (BOOL)isTransactionActive
{
    sqlite3* myDB = [self QLP_sqliteDatabase];
    
    return (!myDB->autoCommit);
}

#pragma mark// ==================================
#pragma mark// Importing Methods
#pragma mark// ==================================

- (QLImportResult)importFromFile:(NSString*)filePath encoding:(NSStringEncoding)encoding columnDelimiter:(NSString*)colDelim endOfRecord:(NSString*)eolDelim table:(NSString*)table dropTableIfItExistsAndRecreate:(BOOL)dropAndRecreateTableFlag clearTableContentsBeforeImporting:(BOOL)clearTableFlag
{
    // Log info if required...
    [self QLP_logIfInDebugMode:_cmd forClass:[self class]];
    
    NSString* fileFullPath = [filePath stringByExpandingTildeInPath];
    
    // Check to see if the available is available
    QLImportResult importFileStatus = [self QLP_isImportFileAvailable:filePath];
    
    if (importFileStatus != QLImportOK)
        return importFileStatus;
    
    // Get the contents of the file and its columns
    NSData* fileData = [NSData dataWithContentsOfFile:fileFullPath];
    NSString* fileContents = [[[NSString alloc] initWithData:fileData encoding:encoding] autorelease];
    
    if (!fileContents)
        return QLImportFileEncodingNotValid;
    
    // Make sure the delimiters exist
    NSRange range = [fileContents rangeOfString:colDelim];
    if (range.location == NSNotFound)
        return QLImportDataWithoutColumnDelimiter;

    range = [fileContents rangeOfString:eolDelim];
    if (range.location == NSNotFound)
        return QLImportDataWithoutRecordDelimiter;
    
    NSArray* fileContentsArray = [fileContents componentsSeparatedByString:eolDelim];
    
    if (!fileContentsArray)
        return QLImportFileColumnsNotFound;
    
    NSArray* importFileColumns = [[fileContentsArray objectAtIndex:0] componentsSeparatedByString:colDelim];
    
    if (!importFileColumns)
        return QLImportFileColumnsNotFound;
    
    [self beginTransaction];
    
    int columnCount = [importFileColumns count];
    
    if (dropAndRecreateTableFlag) {
        // Drop the table
        [self dropTable:table];
        
        // Create the new table
        int i;
        NSMutableArray* datatypes = [[NSMutableArray alloc]init];
        
        for (i = 0; i < columnCount; i++)
            [datatypes addObject: QLString];
        
        if (![self createTable:table withColumns:importFileColumns andDatatypes:datatypes])
            importFileStatus = QLImportFileCouldNotCreateTable;
        
        [datatypes release];
    } else {
        // Make sure the table exists before
        if ([[self tables] indexOfObject:table] == NSNotFound) {
            [self rollbackTransaction];
            return QLImportFileTableNotFound;
        }
        
        // Make sure the columns are equal
        NSSet* databaseColumns = [NSSet setWithArray: [self columnsForTable:table]];
        NSSet* importedFileColumns = [NSSet setWithArray: importFileColumns];
        
        if (![importedFileColumns isSubsetOfSet:databaseColumns]) {
            [self rollbackTransaction];
            return QLImportColumnsNonConforming;
        }
    }
    
    if (clearTableFlag) {
        // Clear the contents of the table
        if ([self QLP_performExecuteQuery:[NSString stringWithFormat:@"DELETE FROM %@;", table]] == NO)
            importFileStatus = QLImportFileCouldNotClearTable;
    }
    
    if (importFileStatus == QLImportOK) {
        int i, count = [fileContentsArray count];
        NSMutableArray* escapedValues = [[NSMutableArray alloc]init];
        
        for (i = 1; i < count; i++) {
            NSArray* values = [[fileContentsArray objectAtIndex:i] componentsSeparatedByString:colDelim];
            if ([values count] != columnCount) {
                importFileStatus = QLImportDataNonConforming;
                break;
            }
            
            int j, valueCount = [values count];
            [escapedValues removeAllObjects];
            
            for (j = 0; j < valueCount; j++) {
                NSString* escapedValue = [[NSString alloc]initWithFormat:@"'%@'", [QuickLiteDatabase prepareStringForQuery:[values objectAtIndex:j]]];
                [escapedValues addObject:escapedValue];
                [escapedValue release];
            }
            
            NSMutableString* sqlQuery = [[NSMutableString alloc]initWithString:@"INSERT INTO "];
            [sqlQuery appendString:table];
            [sqlQuery appendString:@"("];
            [self QLP_sqlString:sqlQuery appendingTags:importFileColumns];
            [sqlQuery appendString:@") VALUES("];
            [self QLP_sqlString:sqlQuery appendingTags:escapedValues];
            [sqlQuery appendString:@");"];
            BOOL dataWasInserted = [self QLP_performExecuteQuery:sqlQuery];
            
            if (!dataWasInserted) {
                NSLog(@"Error when executing the query: %@", sqlQuery);
                [sqlQuery release];
                importFileStatus = QLImportDataHasInvalidCharacter;
                break;
            } else {
                [sqlQuery release];
            }
        }
        
        // Cleanup
        [escapedValues release];
    }
    
    if (importFileStatus == QLImportOK)
        [self commitTransaction];
    else
        [self rollbackTransaction];
    
    return importFileStatus;
}

#pragma mark// ==================================
#pragma mark// Utility Methods
#pragma mark// ==================================

+ (NSString*)escapeQuotesFromString:(NSString*)string
{
    return [QuickLiteDatabase prepareStringForQuery:string];
}

+ (NSString *)UUIDString
{ 
    CFUUIDRef uuid = CFUUIDCreate(NULL); 
    CFStringRef uuidStr = CFUUIDCreateString(NULL, uuid); 
    CFRelease(uuid); 
    [(NSString *)uuidStr autorelease]; 
    return (NSString *)uuidStr; 
} 

- (BOOL)compact
{
    // Log info if required...
    [self QLP_logIfInDebugMode:_cmd forClass:[self class]];
    
    if (![self isTransactionActive]) {
        BOOL didCompact = [self QLP_performExecuteQuery:@"VACUUM;"];
        if (didCompact) {
            NSMutableDictionary* info = [[NSMutableDictionary alloc]init];
            
            [info setObject:[NSNumber numberWithLong:QL_processID] forKey:QLP_ProcessID];
            [info setObject:[self databasePath] forKey:QLDatabasePathIdentifier];
            [info setObject:[NSCalendarDate calendarDate] forKey:QLTimestampIdentifier];
            
            NSDistributedNotificationCenter* center = [NSDistributedNotificationCenter defaultCenter];
            
            // Fast user switching is only available in Panther (Mac OS X 10.3)
#if MAC_OS_X_VERSION_10_3 <= MAC_OS_X_VERSION_MAX_ALLOWED
            [center postNotificationName:QLP_QuickLiteDatabaseDidCompactNotification object:nil userInfo:info options:NSNotificationPostToAllSessions];
#else
            [center postNotificationName:QLP_QuickLiteDatabaseDidCompactNotification object:nil userInfo:info];
#endif
            // Cleanup
            [info release];
        }
        
        return didCompact;
    }
    
    return NO;
}

- (BOOL)integrityCheck
{
    // Log info if required...
    [self QLP_logIfInDebugMode:_cmd forClass:[self class]];
    
    NSString* sqlQuery = @"PRAGMA integrity_check;";
    
    QuickLiteCursor* cursor = [self QLP_performInternalQuickLiteQuery:sqlQuery];
    if (!cursor)
        return NO;
    
    NSString* resultStr = [[cursor rowAtIndex:0]stringForColumn:@"integrity_check"];
    
    return ([resultStr isEqualToString:@"ok"]);
}

- (NSString*)sqliteVersion
{
    // Log info if required...
    [self QLP_logIfInDebugMode:_cmd forClass:[self class]];
    
    NSString* sqlQuery = [NSString stringWithUTF8String: sqlite3_libversion()];
    
    return sqlQuery;
}

- (NSString*)databaseEncoding
{
    // Log info if required...
    [self QLP_logIfInDebugMode:_cmd forClass:[self class]];
    
    NSString* sqlQuery = @"PRAGMA encoding;";
    
    QuickLiteCursor* cursor = [self QLP_performInternalQuickLiteQuery:sqlQuery];
    if (!cursor)
        return @"";
    
    return [[cursor rowAtIndex:0]stringForColumn:@"encoding"];
}

#pragma mark// ==================================
#pragma mark// Query Methods
#pragma mark// ==================================

+ (NSString*)prepareStringForQuery:(NSString*)inString
{
    NSMutableString* string = nil;
    
    if (inString == nil)
        return nil;
    
#if MAC_OS_X_VERSION_10_2 <= MAC_OS_X_VERSION_MAX_ALLOWED
    string = [NSMutableString stringWithString:inString];
    [string replaceOccurrencesOfString:@"'"
                            withString:@"''"
                               options:nil
                                 range:NSMakeRange( 0, [string length] )];
#else
    NSRange range = NSMakeRange( 0, [inString length] );
    NSRange subRange;
    
    subRange = [inString rangeOfString:@"'" options:NSLiteralSearch range:range];
    if( subRange.location == NSNotFound )
        return inString;
    
    string = [NSMutableString stringWithString:inString];
    for( ; subRange.location != NSNotFound && range.length > 0;  )
    {
        subRange = [string rangeOfString:@"'" options:NSLiteralSearch range:range];
        if( subRange.location != NSNotFound )
            [string replaceCharactersInRange:subRange withString:@"''"];
        
        range.location = subRange.location + 2;
        range.length = ( [string length] < range.location ) ? 0 :( [string length] - range.location );
    }
#endif
    
    return string;
}

- (QuickLiteCursor*)performQuery:(NSString*)sqlQuery
{
    // Log info if required...
    [self QLP_logIfInDebugMode:_cmd forClass:[self class]];
    
    return [self QLP_performQuery:sqlQuery cacheMethod:QLP_UseDefaultCacheMethod treatValuesAsString:NO saveSQLStatement:[self sendsSQLStatementWhenNotifyingOfChanges]];
}

- (QuickLiteCursor*)performQuery:(NSString*)sqlQuery cacheMethod:(QLCacheMethod)cacheMethod
{
    // Log info if required...
    [self QLP_logIfInDebugMode:_cmd forClass:[self class]];
    
    return [self QLP_performQuery:sqlQuery cacheMethod:cacheMethod treatValuesAsString:NO saveSQLStatement:[self sendsSQLStatementWhenNotifyingOfChanges]];
}

#pragma mark// ==================================
#pragma mark// Introspection Methods
#pragma mark// ==================================

- (NSArray*)tables
{
    // Log info if required...
    [self QLP_logIfInDebugMode:_cmd forClass:[self class]];
    
    NSArray* allTables = [self QLP_flattenAllTables];
    if ([allTables count] == 0)
        return allTables;
    
    // Remove QuickLite's private table
    NSMutableArray* tempTables = [NSMutableArray arrayWithArray:allTables];
    [tempTables removeObject:QLP_SchemaTable];
    
    return tempTables;
}

- (NSDictionary*)allTables
{
    NSMutableDictionary *allTables = [NSMutableDictionary dictionary];
    
    // Make sure we obtain full column names
    [self QLP_setFullColumnNamesEnabled];
    
    QuickLiteCursor *databasesCursor = [self QLP_performInternalQuickLiteQuery:@"PRAGMA database_list"];
    NSArray *databases = [databasesCursor valuesForColumn:@"name"];
    int i, count = [databases count];
    
    for (i = 0; i < count; i++) {
        NSString* database = [databases objectAtIndex: i];
        QuickLiteCursor* cursor = [self QLP_performInternalQuickLiteQuery:[NSString stringWithFormat:@"SELECT * FROM %@.sqlite_master;", database]];
        if ([self lastErrorID] == QLSuccess) {
            // Get all tables in the database
            NSArray* databaseTables = [cursor valuesForColumn:@"sqlite_master.tbl_name"];
            if ([databaseTables count] > 0) {
                NSSet *tablesPerDatabase = [NSSet setWithArray:databaseTables];
                [allTables setObject: [tablesPerDatabase allObjects] forKey: database];
            }
        }
    }
    
    return allTables;
}

- (NSArray*)columnsForTable:(NSString*)table
{
    // Log info if required...
    [self QLP_logIfInDebugMode:_cmd forClass:[self class]];

    NSString* database = [self QLP_prefixWithDotDelimiter:table];
    if (![database isEqualToString:table]) {
        database = [NSString stringWithFormat:@"%@.", database];
        table = [self QLP_suffixWithDotDelimiter:table];
    } else {
        database = @"";
    }
    
    NSMutableArray* tempTableInfo = [NSMutableArray array];
    
    // Get the SQL statement from sqlite_master
    NSString* sqlMasterQuery = [[NSString alloc]initWithFormat:@"SELECT sql FROM %@sqlite_master WHERE tbl_name = '%@';", database, table];
    NSString* sqlStatement = [[[self QLP_performInternalQuickLiteQuery:sqlMasterQuery] rowAtIndex:0] valueForColumn:@"sqlite_master.sql"];
    
    // Cleanup
    [sqlMasterQuery release];
    
    if (!sqlStatement) {
        // Let's try with the 'sqlite_temp_master' table...
        sqlMasterQuery = [[NSString alloc]initWithFormat:@"SELECT sql FROM %@sqlite_temp_master WHERE tbl_name = '%@';", database, table];
        sqlStatement = [[[self QLP_performInternalQuickLiteQuery:sqlMasterQuery] rowAtIndex:0] valueForColumn:@"sqlite_temp_master.sql"];
        
        // Cleanup
        [sqlMasterQuery release];
    }
    
    if (sqlStatement) {
        // Remove the extra fat
        NSRange leanRange = [sqlStatement rangeOfString:@"("];
        if (leanRange.location != NSNotFound) {
            leanRange.location += 1;
            leanRange.length = [sqlStatement length] - 1 - leanRange.location;
            
            NSString* leanMeat = [sqlStatement substringWithRange:leanRange];
            
            // Segment based on commas
            NSArray* columns = [leanMeat componentsSeparatedByString:@","];
            int i, count = [columns count];
            
            for (i = 0; i < count; i++) {
                // Trim leading spaces
                NSString* columnInfo = [columns objectAtIndex:i];
                
                NSRange charRange;
                charRange.length = 1;
                charRange.location = 0;
                
                while ([[columnInfo substringWithRange:charRange] isEqualToString:@" "]) {
                    charRange.location += 1;
                }
                
                if (charRange.location != 0)
                    columnInfo = [columnInfo substringFromIndex:charRange.location];
                
                NSRange nameRange = [columnInfo rangeOfString:@" "];
                
                NSString* name = nil;
                
                if (nameRange.location == NSNotFound) {
                    name = columnInfo;
                } else {
                    name = [columnInfo substringToIndex:nameRange.location];
                }
                
                [tempTableInfo addObject:name];
            }
        }
    }
    
    return tempTableInfo;
}

- (NSArray*)datatypesForTable:(NSString*)table
{
    // Log info if required...
    [self QLP_logIfInDebugMode:_cmd forClass:[self class]];
    
    NSString* database = [self QLP_prefixWithDotDelimiter:table];
    if (![database isEqualToString:table]) {
        database = [NSString stringWithFormat:@"%@.", database];
        table = [self QLP_suffixWithDotDelimiter:table];
    } else {
        database = @"";
    }
        
    NSMutableArray* tempTableInfo = [NSMutableArray array];
    
    // Get the SQL statement from sqlite_master
    NSString* sqlMasterQuery = [[NSString alloc]initWithFormat:@"SELECT sql FROM %@sqlite_master WHERE tbl_name = '%@';", database, table];
    NSString* sqlStatement = [[[self QLP_performInternalQuickLiteQuery:sqlMasterQuery] rowAtIndex:0] valueForColumn:@"sqlite_master.sql"];
    
    // Cleanup
    [sqlMasterQuery release];
    
    if (!sqlStatement) {
        // Let's try with the 'sqlite_temp_master' table...
        sqlMasterQuery = [[NSString alloc]initWithFormat:@"SELECT sql FROM %@sqlite_temp_master WHERE tbl_name = '%@';", database, table];
        sqlStatement = [[[self QLP_performInternalQuickLiteQuery:sqlMasterQuery] rowAtIndex:0] valueForColumn:@"sqlite_temp_master.sql"];
        
        // Cleanup
        [sqlMasterQuery release];
    }
    
    if (sqlStatement) {
        // Remove the extra fat
        NSRange leanRange = [sqlStatement rangeOfString:@"("];
        if (leanRange.location != NSNotFound) {
            leanRange.location += 1;
            leanRange.length = [sqlStatement length] - 1 - leanRange.location;
            
            NSString* leanMeat = [sqlStatement substringWithRange:leanRange];
            
            // Segment based on commas
            NSArray* columns = [leanMeat componentsSeparatedByString:@","];
            int i, count = [columns count];
            
            for (i = 0; i < count; i++) {
                // Trim leading spaces
                NSString* columnInfo = [columns objectAtIndex:i];
                
                NSRange charRange;
                charRange.length = 1;
                charRange.location = 0;
                
                while ([[columnInfo substringWithRange:charRange] isEqualToString:@" "]) {
                    charRange.location += 1;
                }
                
                if (charRange.location != 0)
                    columnInfo = [columnInfo substringFromIndex:charRange.location];
                
                NSRange nameRange = [columnInfo rangeOfString:@" "];
                
                NSString* datatype = nil;
                
                if (nameRange.location == NSNotFound) {
                    datatype = @"";
                } else {
                    datatype = [columnInfo substringFromIndex:nameRange.location + 1];
                    if ([datatype isEqualToString:@"TEXT"])
                        datatype = QLString;
                }
                
                [tempTableInfo addObject:datatype];
            }
        }
    }
    
    return tempTableInfo;
}

- (NSArray*)indexedColumnsForTable:(NSString*)table
{
    // Log info if required...
    [self QLP_logIfInDebugMode:_cmd forClass:[self class]];
    
    QuickLiteCursor* cursor = [self QLP_performInternalQuickLiteQuery:[NSString stringWithFormat:@"SELECT sqlite_temp_master.name FROM sqlite_temp_master WHERE type = 'index' AND sqlite_temp_master.tbl_name = '%@';", table]];
    if ([cursor rowCount] == 0) {
        cursor = [self QLP_performInternalQuickLiteQuery:[NSString stringWithFormat:@"SELECT sqlite_temp_master.name FROM sqlite_temp_master WHERE type = 'index' AND sqlite_temp_master.tbl_name = '%@';", table]];
        return [cursor valuesForColumn:@"sqlite_temp_master.name"];
    }

    return [cursor valuesForColumn:@"sqlite_master.name"];
}

- (NSArray*)temporaryTables
{
    // Log info if required...
    [self QLP_logIfInDebugMode:_cmd forClass:[self class]];
    
    QuickLiteCursor* cursor = [self QLP_performInternalQuickLiteQuery:@"SELECT * FROM sqlite_temp_master;"];
    
    return [[NSSet setWithArray:[cursor valuesForColumn:@"sqlite_temp_master.tbl_name"]] allObjects];
}

- (NSNumber*)lastRowInserted
{
    // Log info if required...
    [self QLP_logIfInDebugMode:_cmd forClass:[self class]];
    
    unsigned long lastRowID = sqlite3_last_insert_rowid ([self QLP_sqliteDatabase]);
    
    return [NSNumber numberWithUnsignedLong: lastRowID];
}

- (unsigned long)maxRowUIDForTable:(NSString*)table
{
    // Log info if required...
    [self QLP_logIfInDebugMode:_cmd forClass:[self class]];
    
    if (!table)
        return 0;
    
    NSString* column = [NSString stringWithFormat:@"max(%@.%@)", table, QLRecordUID];
    QuickLiteCursor* cursor = [self QLP_performInternalQuickLiteQuery:[NSString stringWithFormat:@"SELECT %@ FROM %@;", column, table]];
    id value = [[cursor valuesForColumn:column] objectAtIndex:0];
    
    if (value == [NSNull null])
        return 0;
    
    return [[NSNumber numberWithDouble:[value doubleValue]]unsignedLongValue];
}

- (int)lastErrorID
{
    return QL_lastErrorID;
}

- (NSString*)lastError
{
    return [[QL_lastError copy]autorelease];
}

- (NSString*)descriptionForValue:(id)value
{
    if ([value isKindOfClass:[NSString class]])
        return value;
    else
        return [value description];
}

#pragma mark// ==================================
#pragma mark// SQLite Tunning Methods
#pragma mark// ==================================

- (void)setBusyTimeout:(unsigned int)msTimeout
{
    sqlite3_busy_timeout([self QLP_sqliteDatabase], msTimeout);
}

- (unsigned int)sessionCacheSize
{
    QuickLiteCursor* cursor = [self QLP_performInternalQuickLiteQuery:@"PRAGMA cache_size;"];
    
    if ([cursor rowCount] > 0)
        return [[cursor QLP_stringForColumn:@"cache_size" andRow:0] intValue];
    
    return 0;
}

- (void)setSessionCacheSize:(unsigned int)numberOfPages
{
    if (numberOfPages < 1000)
        numberOfPages = 1000;
    
    NSString* sqlQuery = [[NSString alloc]initWithFormat:@"PRAGMA cache_size=%ld", numberOfPages];
    [self QLP_performExecuteQuery:sqlQuery];
    [sqlQuery release];
}

- (QLSynchronousMode)synchronousMode
{
    QuickLiteCursor* cursor = [self QLP_performInternalQuickLiteQuery:@"PRAGMA synchronous;"];
    
    if ([cursor rowCount] > 0)
        return [[cursor QLP_stringForColumn:@"synchronous" andRow:0] intValue];
    
    return 0;
}

- (void)setSynchronousMode:(QLSynchronousMode)mode
{	
    switch (mode) {
        case SynchronousModeOff:
            [self QLP_performExecuteQuery:@"PRAGMA synchronous = OFF;"];
            break;
        case SynchronousModeFull:
            [self QLP_performExecuteQuery:@"PRAGMA synchronous = FULL;"];
            break;
        default:
            [self QLP_performExecuteQuery:@"PRAGMA synchronous = NORMAL;"];
            break;
    }
}

- (QLTempStoreMode)tempStoreMode
{
    QuickLiteCursor* cursor = [self QLP_performInternalQuickLiteQuery:@"PRAGMA temp_store;"];
    
    if ([cursor rowCount] > 0)
        return [[cursor QLP_stringForColumn:@"temp_store" andRow:0] intValue];
    
    return 0;
}

- (void)setTempStoreMode:(QLTempStoreMode)mode
{	
    switch (mode) {
        case TempStoreModeFile:
            [self QLP_performExecuteQuery:@"PRAGMA temp_store = FILE;"];
            break;
        case TempStoreModeMemory:
            [self QLP_performExecuteQuery:@"PRAGMA temp_store = MEMORY;"];
            break;
        default:
            [self QLP_performExecuteQuery:@"PRAGMA temp_store = DEFAULT;"];
            break;
    }
}

#pragma mark// ==================================
#pragma mark// Binary Data Methods
#pragma mark// ==================================

- (NSString*)encodeDataToBase64:(NSData*)data
{
    int decodedDataSize = [data length];
    unsigned char *bytes = (unsigned char *)malloc(decodedDataSize);
    
    // Extract the bytes
    [data getBytes:bytes];
    
    unsigned char inBuffer[3];
    unsigned char outBuffer[4];
    int i;
    int segments;
    char *outputBuffer;
    char *base64Buffer;
    
    base64Buffer = outputBuffer = (char*)malloc(decodedDataSize*4/3+4);
    if(NULL == outputBuffer)
        return nil;
    
    while(decodedDataSize > 0) {
        for (i = segments = 0; i < 3; i++) {
            if(decodedDataSize > 0) {
                segments++;
                inBuffer[i] = *bytes;
                bytes++;
                decodedDataSize--;
            } else
                inBuffer[i] = 0;
        }
        
        outBuffer [0] = (inBuffer [0] & 0xFC) >> 2;
        outBuffer [1] = ((inBuffer [0] & 0x03) << 4) | ((inBuffer [1] & 0xF0) >> 4);
        outBuffer [2] = ((inBuffer [1] & 0x0F) << 2) | ((inBuffer [2] & 0xC0) >> 6);
        outBuffer [3] = inBuffer [2] & 0x3F;
        
        switch(segments) {
            case 1:
                sprintf(outputBuffer, "%c%c==",
                        base64Table[outBuffer[0]],
                        base64Table[outBuffer[1]]);
                break;
            case 2:
                sprintf(outputBuffer, "%c%c%c=",
                        base64Table[outBuffer[0]],
                        base64Table[outBuffer[1]],
                        base64Table[outBuffer[2]]);
                break;
            default:
                sprintf(outputBuffer, "%c%c%c%c",
                        base64Table[outBuffer[0]],
                        base64Table[outBuffer[1]],
                        base64Table[outBuffer[2]],
                        base64Table[outBuffer[3]] );
                break;
        }
        
        outputBuffer += 4;
    }
    
    *outputBuffer = 0;
    
    NSString* myBase64Data = [NSString stringWithCString:base64Buffer];
    
    free (base64Buffer);
    
    return myBase64Data;
}

- (NSData*)decodeDataFromBase64:(NSString*)encodedData
{
    const char* source = [encodedData cString];
    unsigned long sourceLength = strlen(source);
    char* destination = (char *)malloc(sourceLength * 3/4 + 8);
    char* destinationPtr = destination;
    
    int length = 0;
    int pivot = 0;
    int i;
    int numSegments;
    unsigned char lastSegment[3];
    unsigned long decodedLength = 0;
    
    while ((source[length] != '=') && source[length])
        length++;
    while (source[length+pivot] == '=')
        pivot++;
    
    numSegments = (length + pivot) / 4;
    
    decodedLength = (numSegments * 3) - pivot;
    
    for(i = 0; i < numSegments - 1; i++) {
        [self QLP_decodeQuantum:(unsigned char *)destination andSource:source];
        destination += 3;
        source += 4;
    }
    
    [self QLP_decodeQuantum:lastSegment andSource:source];
    
    for(i = 0; i < 3 - pivot; i++)
        destination[i] = lastSegment[i];
    
    // Construct a NSData with the decoded data
    NSData* myDummyData = [NSData dataWithBytes:destinationPtr length:decodedLength];
    
    // Cleanup
    free (destinationPtr);
    
    return myDummyData;
}

#pragma mark// ==================================
#pragma mark// QuickLiteDatabase Private Methods
#pragma mark// ==================================

- (sqlite3*)QLP_sqliteDatabase
{
    return QL_sqliteDatabase;
}

- (void)QLP_setLastError:(const char*)sqliteErrorString withID:(int)errorID
{
    [QL_lastError release];
    QL_lastError = nil;
    QL_lastErrorID = errorID;
    
    if (sqliteErrorString != NULL)
        QL_lastError = [[NSString alloc] initWithUTF8String:sqliteErrorString];
}

- (void)QLP_sendSQLStatement:(NSString*)sqlQuery
{
    if (![self sendsSQLStatementWhenNotifyingOfChanges])
        return;
    
    if (!sqlQuery)
        return;
    
    NSMutableDictionary* info = [[NSMutableDictionary alloc]init];
    
    [info setObject:[NSNumber numberWithLong:QL_processID] forKey:QLP_ProcessID];
    [info setObject:[self databasePath] forKey:QLDatabasePathIdentifier];
    [info setObject:[NSCalendarDate calendarDate] forKey:QLTimestampIdentifier];
    [info setObject:sqlQuery forKey:QLSQLStatementIdentifier];
    
    NSDistributedNotificationCenter* center = [NSDistributedNotificationCenter defaultCenter];
    
    // Fast user switching is only available in Panther (Mac OS X 10.3)
#if MAC_OS_X_VERSION_10_3 <= MAC_OS_X_VERSION_MAX_ALLOWED
    [center postNotificationName:QLDatabaseHasSentSQLStatementNotification object:nil userInfo:info options:NSNotificationPostToAllSessions];
#else
    [center postNotificationName:QLDatabaseHasSentSQLStatementNotification object:nil userInfo:info];
#endif
    
    // Cleanup
    [info release];
}

- (BOOL)QLP_performExecuteQuery:(NSString*)sqlQuery
{
    return [self QLP_performExecuteQuery:sqlQuery saveSQLStatement:[self sendsSQLStatementWhenNotifyingOfChanges]];
}

- (BOOL)QLP_performExecuteQuery:(NSString*)sqlQuery saveSQLStatement:(BOOL)saveSQL
{
    /* Validate arguments */
    if (![self QLP_sqliteDatabase]) {
        [self QLP_setLastError:"[QuickLiteDatabase QLP_performExecuteQuery:] failed because the database is closed." withID:QLP_UnknownError];
        return NO;
    }
    
    if (!sqlQuery) {
        [self QLP_setLastError:"[QuickLiteDatabase QLP_performExecuteQuery:] failed because the query is nil." withID:QLP_UnknownError];
        return NO;
    }
    
    // Remember the SQL statement, if needed
    [self QLP_sendSQLStatement:sqlQuery];
    
    // Set the busy timeout (by default is 3 seconds)
    [self setBusyTimeout:3 * 1000];
    
    // Make sure we obtain full column names
    [self QLP_setFullColumnNamesEnabled];
    
    sqlite3_stmt *QL_sqliteVM;
    const char *query_tail = [sqlQuery UTF8String];
    
    do {
        int result = sqlite3_prepare([self QLP_sqliteDatabase], query_tail, -1, &QL_sqliteVM, &query_tail);
        const char* errMsg = NULL;
        
        if (result == QLSuccess) {
            BOOL waitingForRow = YES;
            
            do {
                result = sqlite3_step(QL_sqliteVM);
                
                switch (result) {
                    case SQLITE_BUSY:
                        break;
                    case SQLITE_OK:
                    case SQLITE_DONE:
                        waitingForRow = NO;
                        break;
                    case SQLITE_ROW:
                        waitingForRow = NO;
                        break;
                    default:
                        errMsg = sqlite3_errmsg([self QLP_sqliteDatabase]);
                        [self QLP_logIfInDebugMode:[NSString stringWithUTF8String:errMsg]];
                        [self QLP_setLastError:errMsg withID: result];
                        waitingForRow = NO;
                        break;
                }
            } while (waitingForRow);
            
            result = sqlite3_finalize(QL_sqliteVM);
            if (result != QLSuccess) {
                const char* errMsg = sqlite3_errmsg([self QLP_sqliteDatabase]);
                [self QLP_logIfInDebugMode:[NSString stringWithUTF8String:errMsg]];
                [self QLP_setLastError:errMsg withID: result];
            } else {
                [self QLP_setLastError: NULL withID: QLSuccess];
            }
        } else {
            errMsg = sqlite3_errmsg([self QLP_sqliteDatabase]);
            [self QLP_logIfInDebugMode:[NSString stringWithUTF8String:errMsg]];
            [self QLP_setLastError:errMsg  withID: result];
        }
        
    } while ((strlen(query_tail) > 0) && ([self lastErrorID] == QLSuccess));
    
    return ([self lastErrorID] == QLSuccess);
}

- (QuickLiteCursor*)QLP_performInternalQuickLiteQuery:(NSString*)sqlQuery
{
    return [self QLP_performQuery:sqlQuery cacheMethod:CacheAllData treatValuesAsString:YES saveSQLStatement:NO];
}

- (QuickLiteCursor*)QLP_performInternalQuickLiteQuery:(NSString*)sqlQuery cacheMethod:(QLCacheMethod)cacheMethod
{
    return [self QLP_performQuery:sqlQuery cacheMethod:cacheMethod treatValuesAsString:YES saveSQLStatement:NO];
}

- (QuickLiteCursor*)QLP_performInternalQuickLiteQuery:(NSString*)sqlQuery cacheMethod:(QLCacheMethod)cacheMethod treatValuesAsString:(BOOL)treatAsString
{
    return [self QLP_performQuery:sqlQuery cacheMethod:cacheMethod treatValuesAsString:treatAsString saveSQLStatement:NO];
}

- (QuickLiteCursor*)QLP_performQuery:(NSString*)sqlQuery cacheMethod:(QLCacheMethod)cacheMethod treatValuesAsString:(BOOL)treatAsString saveSQLStatement:(BOOL)saveSQL
{
    // Safeguard measure
    if (![self isDatabaseOpen]) {
        [self QLP_setLastError:"[QuickLiteDatabase performQuery:] failed because the database is closed." withID:QLP_UnknownError];
        return nil;
    }
    
    // Remember the SQL statement, if needed
    [self QLP_sendSQLStatement:sqlQuery];
    
    NSString* prefixSelect = @"select";
    NSString* prefixPragma = @"pragma";
    QuickLiteCursor* cursor = nil;
    
    if (([sqlQuery compare:prefixSelect options:NSCaseInsensitiveSearch range:NSMakeRange(0, [prefixSelect length])] == NSOrderedSame) ||
        ([sqlQuery compare:prefixPragma options:NSCaseInsensitiveSearch range:NSMakeRange(0, [prefixPragma length])] == NSOrderedSame)) {
        
        cursor = [[[QuickLiteCursor alloc]QLP_initWithDatabase:self withQuery:sqlQuery cacheMethod:cacheMethod treatValuesAsString:treatAsString] autorelease];
    } else {
        [self QLP_performExecuteQuery:sqlQuery saveSQLStatement:saveSQL];
    }
    
    return cursor;
}

- (void)QLP_decodeQuantum:(unsigned char*)dest andSource:(const char *)src
{
    unsigned int x = 0;
    int i;
    for(i = 0; i < 4; i++) {
        if(src[i] >= 'A' && src[i] <= 'Z')
            x = (x << 6) + (unsigned int)(src[i] - 'A' + 0);
        else if(src[i] >= 'a' && src[i] <= 'z')
            x = (x << 6) + (unsigned int)(src[i] - 'a' + 26);
        else if(src[i] >= '0' && src[i] <= '9')
            x = (x << 6) + (unsigned int)(src[i] - '0' + 52);
        else if(src[i] == '+')
            x = (x << 6) + 62;
        else if(src[i] == '/')
            x = (x << 6) + 63;
        else if(src[i] == '=')
            x = (x << 6);
    }
    
    dest[2] = (unsigned char)(x & 255);
    x >>= 8;
    dest[1] = (unsigned char)(x & 255);
    x >>= 8;
    dest[0] = (unsigned char)(x & 255);
}

- (QLDatatype)QLP_datatypeForColumn:(NSString*)tableAndColumn
{
    NSString* table = [self QLP_prefixWithDotDelimiter:tableAndColumn];
    NSString* column = [self QLP_suffixWithDotDelimiter:tableAndColumn];
    
    return [self QLP_datatypeForTable:(NSString*)table column:(NSString*)column];
}

- (QLDatatype)QLP_datatypeForTable:(NSString*)table column:(NSString*)column
{
    if ((!table) || (!column))
        return QL_Unknown;
    
    NSString* datatype = nil;
    
    // Check to see if the schema has been cached; take advantage of it if possible...
    if (QL_schema) {
        datatype = [[QL_schema objectForKey:table]objectForKey:column];
    } else {
        NSString* sqlQuery = [[NSString alloc]initWithFormat:@"SELECT %@ from %@ WHERE %@ = '%@' AND %@ = '%@';", QLP_DatatypeIdentifier, QLP_SchemaTable, QLP_TableIdentifier, table, QLP_ColumnIdentifier, column];
        
        QuickLiteCursor* cursor = [self QLP_performInternalQuickLiteQuery:sqlQuery];
        
        // Cleanup
        [sqlQuery release];
        
        datatype = [[cursor rowAtIndex:0]stringForColumn:QLP_FullDatatypeIdentifier];
    }
    
    if (datatype == nil)
        return QL_Unknown;

    if ([datatype isEqualToString:QLString]) return QL_String;
    if ([datatype isEqualToString:QLNumber]) return QL_Number;
    if ([datatype isEqualToString:QLBoolean]) return QL_Boolean;
    if ([datatype isEqualToString:QLDateTime]) return QL_DateTime;
    if ([datatype isEqualToString:QLContainer]) return QL_Container;
    if ([datatype caseInsensitiveCompare:QLRecordUIDDatatype] == NSOrderedSame) return QL_RowID;
    
    return QL_Unknown;
}

- (QLImportResult)QLP_isImportFileAvailable:(NSString*)filePath
{
    NSFileManager *manager = [NSFileManager defaultManager];
    NSString* fileFullPath = [filePath stringByExpandingTildeInPath];
    BOOL fileExists, isDir;
    
    fileExists = [manager fileExistsAtPath:fileFullPath isDirectory:&isDir];
    
    if (!fileExists)
        return QLImportFilePathNotFound;
    
    if (isDir)
        return QLImportFilePathIsDirectory;
    
    return QLImportOK;
}

- (void)QLP_registerModifiedCursor:(QuickLiteCursor*)cursor
{
    if (!QL_modifiedCursors)
        QL_modifiedCursors = [[NSMutableSet alloc]init];
    
    [QL_modifiedCursors addObject: cursor];
}

- (void)QLP_deregisterModifiedCursor:(QuickLiteCursor*)cursor
{
    [QL_modifiedCursors removeObject: cursor];
}

- (void)QLP_setFullColumnNamesEnabled
{
    [self QLP_executeSingleSQLStatement: @"PRAGMA short_column_names = OFF;"];
    [self QLP_executeSingleSQLStatement: @"PRAGMA full_column_names = ON;"];
}

- (void)QLP_logIfInDebugMode:(SEL)cmd forClass:(Class)aClass
{
    if ([self isInDebugMode])
        NSLog(@"[%@] %s", aClass, cmd);
}

- (void)QLP_logIfInDebugMode:(NSString*)string
{
    if ([self isInDebugMode])
        NSLog(@"%@", string);
}

- (NSArray*)QLP_flattenAllTables
{
    NSMutableSet* flattenedTables = [NSMutableSet set];
    NSDictionary* allTables = [self allTables];
    NSEnumerator *enumerator = [allTables keyEnumerator];
    NSString* database;
    BOOL addPrefix = ([allTables count] > 1);

    while ((database = [enumerator nextObject])) {
        NSArray* databaseTables = [allTables objectForKey:database];
        
        if ((addPrefix) && ([database hasPrefix:@"main"] == NO)) {
            int i, count = [databaseTables count];
            for (i = 0; i < count; i++) {
                [flattenedTables addObject:[NSString stringWithFormat:@"%@.%@", database, [databaseTables objectAtIndex:i]]];
            }
        } else {
            [flattenedTables addObjectsFromArray:databaseTables];
        }
    }
    
    return [flattenedTables allObjects];
}

- (void)QLP_executeSingleSQLStatement:(NSString*)sqlString
{
    /* Validate arguments */
    if (![self QLP_sqliteDatabase]) {
        [self QLP_setLastError:"[QuickLiteDatabase QLP_executeSingleSQLStatement:] failed because the database is closed." withID:QLP_UnknownError];
    }
    
    // Set the busy timeout (by default is 3 seconds)
    [self setBusyTimeout:3 * 1000];
    
    sqlite3_stmt *QL_sqliteVM;
    const char *query_tail = [sqlString UTF8String];
    
    do {
        int result = sqlite3_prepare([self QLP_sqliteDatabase], query_tail, -1, &QL_sqliteVM, &query_tail);
        const char* errMsg = NULL;
        
        if (result == QLSuccess) {
            BOOL waitingForRow = YES;
            
            do {
                result = sqlite3_step(QL_sqliteVM);
                
                switch (result) {
                    case SQLITE_BUSY:
                        break;
                    case SQLITE_OK:
                    case SQLITE_DONE:
                        waitingForRow = NO;
                        break;
                    case SQLITE_ROW:
                        waitingForRow = NO;
                        break;
                    default:
                        errMsg = sqlite3_errmsg([self QLP_sqliteDatabase]);
                        [self QLP_logIfInDebugMode:[NSString stringWithUTF8String:errMsg]];
                        [self QLP_setLastError:errMsg withID: result];
                        waitingForRow = NO;
                        break;
                }
            } while (waitingForRow);
            
            result = sqlite3_finalize(QL_sqliteVM);
            if (result != QLSuccess) {
                const char* errMsg = sqlite3_errmsg([self QLP_sqliteDatabase]);
                [self QLP_logIfInDebugMode:[NSString stringWithUTF8String:errMsg]];
                [self QLP_setLastError:errMsg withID: result];
            } else {
                [self QLP_setLastError: NULL withID: QLSuccess];
            }
        } else {
            errMsg = sqlite3_errmsg([self QLP_sqliteDatabase]);
            [self QLP_logIfInDebugMode:[NSString stringWithUTF8String:errMsg]];
            [self QLP_setLastError:errMsg  withID: result];
        }
        
    } while ((strlen(query_tail) > 0) && ([self lastErrorID] == QLSuccess));
}

#pragma mark// ==================================
#pragma mark// Notification Methods
#pragma mark// ==================================

- (void)_communicateDatabaseHasChanged:(NSNotification*)info
{
    // Check whether the notification has to do with our own database
    if ([[[info userInfo] objectForKey:QLDatabasePathIdentifier] isEqualToString:[self databasePath]]) {
        // Get the process ID that posted the notification
        unsigned long notificationProcessID = [[[info userInfo] objectForKey:QLP_ProcessID]longValue];
        
        // Let's take care of it if someone else performed the change
        if (([self isDatabaseOpen]) && (notificationProcessID != QL_processID))
            [self QLP_rebuildDatatypeCache];
        
        // Let our app know that we're ready to rumble
        NSNotificationCenter* center = [NSNotificationCenter defaultCenter];
        [center postNotificationName:QLDatabaseHasChangedNotification object:[info userInfo]];
    }
}

- (void)_communicateCompactingDoneChanged:(NSNotification*)info
{
    // Check whether the notification has to do with our own database
    if ([[[info userInfo] objectForKey:QLDatabasePathIdentifier] isEqualToString:[self databasePath]]) {
        // Get the process ID that posted the notification
        unsigned long notificationProcessID = [[[info userInfo] objectForKey:QLP_ProcessID]longValue];
        
        // Let's take care of it if someone else performed the compacting
        if (([self isDatabaseOpen]) && (notificationProcessID != QL_processID))
            [self QLP_rebuildDatatypeCache];
    }
}

@end