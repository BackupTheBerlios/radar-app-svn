/*
 *  QuickLiteCursor.m
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

#import "QuickLiteCursor.h"
#import "QuickLiteCursorPrivate.h"
#import "QuickLiteRowPrivate.h"
#import "QuickLiteDatabasePrivate.h"
#import "QuickLiteDatabaseExtras.h"

#import "sqlite3.h"

@implementation QuickLiteCursor

- (id)QLP_initWithDatabase:(QuickLiteDatabase*)database withQuery:(NSString*)sqlQuery cacheMethod:(QLCacheMethod)cacheMethod treatValuesAsString:(BOOL)treatAsString
{
    if (database == nil)
        return nil;
	
    if (!sqlQuery)
        return nil;
	
    if (![self init])
        return nil;
    
    QL_cache = [[NSMutableArray alloc]init];
    QL_cacheEdits = [[NSMutableDictionary alloc]init];
    QL_cacheInserts = [[NSMutableArray alloc]init];
    QL_cacheDeletes = [[NSMutableDictionary alloc]init];

    // Initialize some vars
    QL_quickLiteDatabase = database;
    QL_sqlQuery = [sqlQuery copy];
    QL_treatAsString = treatAsString;
    
    // Register 'QLP_QuickLiteDatabaseDidCloseNotification'
    NSNotificationCenter* center = [NSNotificationCenter defaultCenter];
    [center addObserver:self selector:@selector(QLP_releaseOurQuickLiteDatabase:) name:QLP_QuickLiteDatabaseDidCloseNotification object:nil];

    // Pick up the caching method if set to default
    if (cacheMethod == QLP_UseDefaultCacheMethod)
        QL_cacheMethod = [QL_quickLiteDatabase cacheMethod];
    else
        QL_cacheMethod = cacheMethod;
    
    if (![self QLP_setupCursor]) {
        [self release];
        return nil;
    }

    return self;
}

- (id)init
{
    if (![super init])
        return nil;
    
    QL_quickLiteDatabase = nil;
    QL_sqlQuery = nil;
    QL_treatAsString = nil;
    QL_sqliteVM = NULL;
    
    QL_cacheTables = nil;
    QL_cacheColumns = nil;
    QL_cache = nil;
    QL_cacheEdits = nil;
    QL_cacheInserts = nil;
    QL_cacheDeletes = nil;
    
    QL_cacheMethod = QLP_UseDefaultCacheMethod;
	
    return self;
}

- (void)dealloc
{
    if ([QL_cache count] > 0)
            [QL_quickLiteDatabase QLP_deregisterModifiedCursor: self];
    [QL_cache release];
	
    [QL_cacheTables release];
    [QL_cacheColumns release];
    [QL_cacheEdits release];
    [QL_cacheInserts release];
    [QL_cacheDeletes release];
	
    if (QL_quickLiteDatabase) {
        QL_quickLiteDatabase = nil;
        // We no longer listen at this point...
        [[NSNotificationCenter defaultCenter] removeObserver:self name:QLP_QuickLiteDatabaseDidCloseNotification object:nil];
    }

    [QL_sqlQuery release];
    
    [super dealloc];
}

- (NSString*)description
{
    NSMutableString* tempValue = [NSMutableString string];
    int columnCount = [self columnCount], rowCount = [self rowCount];
    
    [tempValue appendString:[NSString stringWithFormat:@"Number of columns:%d | Number of rows:%ld\n", columnCount, rowCount]];
    [tempValue appendString:@"Caching method: "];
    switch (QL_cacheMethod) {
        case CacheAllData:
            [tempValue appendString:@"CacheAllData"];
            break;
        case CacheDataOnDemand:
            [tempValue appendString:@"CacheDataOnDemand"];
            break;
        case DoNotCacheData:
            [tempValue appendString:@"DoNotCacheData"];
            break;
    }
    [tempValue appendString:@"\n"];
    return tempValue;
}

- (NSString*)fullDescription
{
    return [self fullDescription: 0];
}

- (NSString*)fullDescription:(unsigned long)numberOfRows
{
    NSArray* columns = [self columns];
    
    NSMutableString* tempValue = [NSMutableString string];
    int i, j, columnCount = [self columnCount], rowCount = [self rowCount];
    
    if ((numberOfRows != 0) && (numberOfRows <= rowCount))
        rowCount = numberOfRows;
	
    [tempValue appendString:[NSString stringWithFormat:@"Number of columns:%d | Number of rows:%ld\n", columnCount, rowCount]];
    [tempValue appendString:@"Caching method: "];
    switch (QL_cacheMethod) {
            case CacheAllData:
                    [tempValue appendString:@"CacheAllData"];
                    break;
            case CacheDataOnDemand:
                    [tempValue appendString:@"CacheDataOnDemand"];
                    break;
            case DoNotCacheData:
                    [tempValue appendString:@"DoNotCacheData"];
                    break;
    }
    [tempValue appendString:@"\n"];
    
    [tempValue appendString:@"Row # | "];
	
    // Append the columns
    for (i = 0; i < columnCount; i++) {
        if (i > 0)
            [tempValue appendString:@" | "];
        [tempValue appendString:[columns objectAtIndex:i]];
    }
    [tempValue appendString:@"\n"];
	
    if (rowCount == 0) {
        [tempValue appendString:@"<Cursor doesn't contain rows>"];
    } else {
        // Append the rows
        for (i = 0; i < rowCount; i++) {
            if (i > 0)
                [tempValue appendString:@"\n"];
        
            [tempValue appendString:[NSString stringWithFormat:@"[%ld] ", i]];
            
            for (j = 0; j < columnCount; j++) {
                if (j > 0)
                    [tempValue appendString:@" | "];
                NSString* columnValue = [self QLP_valueForColumn:[columns objectAtIndex:j] andRow:i treatValuesAsString:YES];
                if (columnValue != nil) {
                    if ([columnValue isKindOfClass:[NSNull class]])
                        [tempValue appendString:@"NULL"];
                    else
                        [tempValue appendString:columnValue];
                } else {
                    if ([QL_quickLiteDatabase isDatabaseOpen])
                        [tempValue appendString:@"NULL"];
                    else
                        [tempValue appendString:@"< n/a >"];
                }
            }
        }
    }
    
    return tempValue;
}

- (BOOL)hasUnsavedChanges
{
    return (([QL_cacheEdits count] > 0) || ([QL_cacheInserts count] > 0) || ([QL_cacheDeletes count] > 0));
}

- (BOOL)save
{
    // Log info if required...
    [QL_quickLiteDatabase QLP_logIfInDebugMode:_cmd forClass:[self class]];

    return [self QLP_saveAndDeregisterCursor:YES];
}

- (void)revert
{	
    // Log info if required...
    [QL_quickLiteDatabase QLP_logIfInDebugMode:_cmd forClass:[self class]];

    [self QLP_revertAndDeregisterCursor:YES];
}

- (void)refresh
{
    // Log info if required...
    [QL_quickLiteDatabase QLP_logIfInDebugMode:_cmd forClass:[self class]];

    if ([QL_quickLiteDatabase isDatabaseOpen])
            [self QLP_setupCursor];
}

#pragma mark// ==================================
#pragma mark// Accessor Methods
#pragma mark// ==================================

- (NSString*)sqlQuery
{
    return [[QL_sqlQuery copy]autorelease];
}

- (unsigned long)rowCount
{
    return ([QL_cache count] + [QL_cacheInserts count]);
}

- (NSRange)rangeOfInsertedRows
{
    if ([QL_cacheInserts count] == 0)
            return NSMakeRange (NSNotFound, 0);

    return NSMakeRange ([self rowCount] - [QL_cacheInserts count], [QL_cacheInserts count]);
}

- (unsigned int)columnCount
{
    return [QL_cacheColumns count];
}

- (NSArray*)tables
{
    return [QL_cacheTables allObjects];
}

- (NSArray*)columns
{
    return [QL_cacheColumns allObjects];
}

- (NSArray*)columnsForTable:(NSString*)table
{
    if (!table) {
        [QL_quickLiteDatabase QLP_setLastError:"[QuickLiteCursor columnsForTable:] failed: table is nil." withID: QLP_UnknownError];
        return nil;
    }

    // Obtain a set with the names of the tables found in the cursor
    NSMutableSet* tempColumns = [[NSMutableSet alloc]init];
    NSString* tablePrefix = [NSString stringWithFormat:@"%@.", table];
    
    NSEnumerator *enumerator = [QL_cacheColumns objectEnumerator];
    NSString* column;
    
    while ((column = [enumerator nextObject])) {
        if ([column hasPrefix:tablePrefix]) {
            NSRange range = [column rangeOfString:@"."];
            if (range.location != NSNotFound) {
                [tempColumns addObject:[column substringFromIndex:range.location + 1]];
            }
        }
    }
    
    NSArray* columns = [tempColumns allObjects];
	
    // Cleanup...
    [tempColumns release];
	
    return columns;
}

- (BOOL)setValue:(id)value forColumn:(NSString*)tableAndColumn
{
    // Log info if required...
    [QL_quickLiteDatabase QLP_logIfInDebugMode:_cmd forClass:[self class]];
    
    unsigned long numberOfSuccesses, i, count = [self rowCount];
    if (count == 0)
        return NO;
    
    numberOfSuccesses = 0;
    
    for (i = 0; i < count; i++) {
        if ([self QLP_setValue:value forColumn:tableAndColumn forRow:i])
            numberOfSuccesses++;
    }
    
    if (numberOfSuccesses > 0)
        [QL_quickLiteDatabase QLP_registerModifiedCursor: self];
    
    return (numberOfSuccesses == count);
}

- (id)valueForColumn:(NSString*)tableAndColumn andRow:(unsigned long)rowIndex
{
    // Log info if required...
    [QL_quickLiteDatabase QLP_logIfInDebugMode:_cmd forClass:[self class]];

    return [self QLP_valueForColumn:tableAndColumn andRow:rowIndex treatValuesAsString:NO];
}

- (BOOL)boolValueForColumn:(NSString*)tableAndColumn andRow:(unsigned long)rowIndex
{
    // Log info if required...
    [QL_quickLiteDatabase QLP_logIfInDebugMode:_cmd forClass:[self class]];
    
    QLDatatype datatype = [QL_quickLiteDatabase QLP_datatypeForColumn:tableAndColumn];
    if (!((datatype == QL_Number) || (datatype == QL_Boolean) || (datatype == QL_RowID))) {
        [QL_quickLiteDatabase QLP_setLastError:"[QuickLiteCursor boolValueForColumn:] failed: tableAndColumn datatype is not of type QLNumber, QLBoolean or QL_RowID." withID: QLP_UnknownError];
        return NO;
    }
    
    // Prepare the VM
    sqlite3_stmt* sqliteVM = NULL;
    [self QLP_initializeVM:&sqliteVM withTableColumn:tableAndColumn andRow:rowIndex];
    
    if	(sqliteVM) {
        double value = sqlite3_column_double(sqliteVM, 0);
        // Clear the VM
        sqlite3_finalize(sqliteVM);
        return (value > 0);
    }
    
    return [[self valueForColumn:tableAndColumn andRow:rowIndex]boolValue];
}

- (int)intValueForColumn:(NSString*)tableAndColumn andRow:(unsigned long)rowIndex
{
    // Log info if required...
    [QL_quickLiteDatabase QLP_logIfInDebugMode:_cmd forClass:[self class]];
    
    QLDatatype datatype = [QL_quickLiteDatabase QLP_datatypeForColumn:tableAndColumn];
    if (!((datatype == QL_Number) || (datatype == QL_RowID))) {
        [QL_quickLiteDatabase QLP_setLastError:"[QuickLiteCursor intValueForColumn:] failed: tableAndColumn datatype is not of type QLNumber or QL_RowID." withID: QLP_UnknownError];
        return NO;
    }
    
    // Prepare the VM
    sqlite3_stmt* sqliteVM = NULL;
    
    [self QLP_initializeVM:&sqliteVM withTableColumn:tableAndColumn andRow:rowIndex];
    
    if	(sqliteVM) {
        int value = sqlite3_column_int(sqliteVM, 0);
        // Clear the VM
        sqlite3_finalize(sqliteVM);
        return value;
    }
    
    return [[self valueForColumn:tableAndColumn andRow:rowIndex]intValue];
}

- (long long)longLongValueForColumn:(NSString*)tableAndColumn andRow:(unsigned long)rowIndex
{
    // Log info if required...
    [QL_quickLiteDatabase QLP_logIfInDebugMode:_cmd forClass:[self class]];
    
    QLDatatype datatype = [QL_quickLiteDatabase QLP_datatypeForColumn:tableAndColumn];
    if (!((datatype == QL_Number) || (datatype == QL_RowID))) {
        [QL_quickLiteDatabase QLP_setLastError:"[QuickLiteCursor longLongValueForColumn:] failed: tableAndColumn datatype is not of type QLNumber or QL_RowID." withID: QLP_UnknownError];
        return NO;
    }
    
    // Prepare the VM
    sqlite3_stmt* sqliteVM = NULL;
    [self QLP_initializeVM:&sqliteVM withTableColumn:tableAndColumn andRow:rowIndex];
    
    if	(sqliteVM) {
        long long value = sqlite3_column_int64(sqliteVM, 0);
        // Clear the VM
        sqlite3_finalize(sqliteVM);
        return value;
    }
    
    return [[self valueForColumn:tableAndColumn andRow:rowIndex]longLongValue];
}

- (double)doubleValueForColumn:(NSString*)tableAndColumn andRow:(unsigned long)rowIndex
{
    // Log info if required...
    [QL_quickLiteDatabase QLP_logIfInDebugMode:_cmd forClass:[self class]];
    
    QLDatatype datatype = [QL_quickLiteDatabase QLP_datatypeForColumn:tableAndColumn];
    if (!((datatype == QL_Number) || (datatype == QL_RowID))) {
        [QL_quickLiteDatabase QLP_setLastError:"[QuickLiteCursor doubleValueForColumn:] failed: tableAndColumn datatype is not of type QLNumber or QL_RowID." withID: QLP_UnknownError];
        return NO;
    }
    
    // Prepare the VM
    sqlite3_stmt* sqliteVM = NULL;
    [self QLP_initializeVM:&sqliteVM withTableColumn:tableAndColumn andRow:rowIndex];
    
    if	(sqliteVM) {
        double value = sqlite3_column_double(sqliteVM, 0);
        // Clear the VM
        sqlite3_finalize(sqliteVM);
        return value;
    }
    
    return [[self valueForColumn:tableAndColumn andRow:rowIndex]doubleValue];
}

- (const unsigned char*)textValueForColumn:(NSString*)tableAndColumn andRow:(unsigned long)rowIndex
{
    // Log info if required...
    [QL_quickLiteDatabase QLP_logIfInDebugMode:_cmd forClass:[self class]];
    
    QLDatatype datatype = [QL_quickLiteDatabase QLP_datatypeForColumn:tableAndColumn];
    if (datatype != QL_String) {
        [QL_quickLiteDatabase QLP_setLastError:"[QuickLiteCursor textValueForColumn:] failed: tableAndColumn datatype is not of type QLString." withID: QLP_UnknownError];
        return 0;
    }
    
    // Prepare the VM
    sqlite3_stmt* sqliteVM = NULL;
    [self QLP_initializeVM:&sqliteVM withTableColumn:tableAndColumn andRow:rowIndex];
    
    if (sqliteVM) {
        const unsigned char* value = sqlite3_column_text(sqliteVM, 0);
        // Clear the VM
        sqlite3_finalize(sqliteVM);
        return value;
    }
    
    return (const unsigned char*)[[self valueForColumn:tableAndColumn andRow:rowIndex]UTF8String];
}

#pragma mark// ==================================
#pragma mark// Cursor Methods
#pragma mark// ==================================

- (QuickLiteRow*)rowAtIndex:(unsigned int)rowIndex
{
    if (rowIndex >= [self rowCount]) {
    [QL_quickLiteDatabase QLP_setLastError:[[NSString stringWithFormat:@"[QuickLiteCursor rowAtIndex:] failed: index %ld is out of bounds.", rowIndex]UTF8String] withID: QLP_UnknownError];
        return nil;
    }

    return [[[QuickLiteRow alloc]QLP_initWithCursor:self withRow:rowIndex] autorelease];
}

- (NSArray*)valuesForColumn:(NSString*)tableAndColumn
{
    NSMutableArray *values = [NSMutableArray array];
    unsigned long i, count = [self rowCount];
    
    for (i = 0; i < count; i++) {
        id value = [self valueForColumn:tableAndColumn andRow:i];
        if (value)
            [values addObject:value];
    }
    
    return values;
}

- (NSDictionary*)valuesForRow:(unsigned long)rowIndex
{
    if (rowIndex >= [self rowCount]) {
    [QL_quickLiteDatabase QLP_setLastError:[[NSString stringWithFormat:@"[QuickLiteCursor valuesForRow:] failed: rowIndex %ld is out of bounds.", rowIndex]UTF8String] withID: QLP_UnknownError];
        return nil;
    }

    NSMutableDictionary* values = [NSMutableDictionary dictionary];
    
    if (QL_cacheMethod != CacheAllData) {
        NSEnumerator *enumerator = [QL_cacheTables objectEnumerator];
        NSString* table;
        BOOL weHaveProblems = NO;

        while (table = [enumerator nextObject]) {
            NSString* rowUIDColumn = [self QLP_rowIDColumnForTable:table];
            if (!rowUIDColumn) {
                // Set error string
                weHaveProblems = YES;
                break;
            }
            NSNumber* rowUID =[[QL_cache objectAtIndex:rowIndex]objectForKey:rowUIDColumn];
            if (!rowUID) {
                // Set error string
                weHaveProblems = YES;
                break;
            }
            NSArray* columns = [self columnsForTable:table];
            if ([columns count] < 1) {
                // Set error string
                weHaveProblems = YES;
                break;
            }
            
            // Construct a query to obtain the data at once
            NSMutableString* sqlQuery = [[NSMutableString alloc]initWithString:@"SELECT "];
            [QL_quickLiteDatabase QLP_sqlString:sqlQuery appendingTags:columns];
            [sqlQuery appendString:[NSString stringWithFormat:@" FROM %@ WHERE %@ = '%@';", table, QLRecordUID, rowUID]];
            QuickLiteCursor* cursor = [QL_quickLiteDatabase QLP_performInternalQuickLiteQuery:sqlQuery];
            [sqlQuery release];
                
            // Add the data from disk to the dictionary
            NSDictionary* diskData = [cursor valuesForRow:0];
            if (!diskData) {
                [QL_quickLiteDatabase QLP_setLastError:"[QuickLiteCursor valuesForRow:] failed: couldn't retrieve the data from disk." withID: QLP_UnknownError];
                return nil;
            }

            [values addEntriesFromDictionary:diskData];

            // Adjust dictionary data with QuickEdit data
            [self QLP_adjustDictionaryValuesWithQuickEditData:values forRow:rowIndex];
        }
    } else {
        // Add the data from the cache
        NSDictionary* data = [QL_cache objectAtIndex:rowIndex];
        if (!data) {
            [QL_quickLiteDatabase QLP_setLastError:"[QuickLiteCursor valuesForRow:] failed: couldn't retrieve the data from the cache." withID: QLP_UnknownError];
            return nil;
        }

        [values addEntriesFromDictionary:data];
        
        // Adjust dictionary data with QuickEdit data
        [self QLP_adjustDictionaryValuesWithQuickEditData:values forRow:rowIndex];
    }
    
    // Remove the UUID from the key list
    [values removeObjectForKey:QLP_UUID];

    // Let's make is immutable, for safety!
    return [NSDictionary dictionaryWithDictionary:values];
}

- (BOOL)insertRowWithValues:(NSArray*)values forColumns:(NSArray*)columns
{
    long i, valuesCount = [values count], columnsCount = [columns count];
    
    // Some sanity check can't hurt...
    if ((valuesCount == 0) || (columnsCount == 0) || (valuesCount != columnsCount))
        return NO;
    
    BOOL isInsertionOK = YES;
    
    // Check that all columns are included in the cache...
    for (i = 0; i < columnsCount; i++) {
        if (![QL_cacheColumns containsObject:[columns objectAtIndex:i]]) {
            isInsertionOK = NO;
            break;
        }
    }
    
    if (isInsertionOK) {
        NSMutableDictionary* rowInfo = [[NSMutableDictionary alloc]init];
        
        for (i = 0; i < valuesCount; i++) {
            QLDatatype columnDatatype = [QL_quickLiteDatabase QLP_datatypeForColumn:[columns objectAtIndex:i]];
            id value = [values objectAtIndex:i];
            
            if ([value isKindOfClass:[NSNull class]] == NO) {
                switch (columnDatatype) {
                    case QL_String:
                        if (![value isKindOfClass:[NSString class]])
                            isInsertionOK = NO;
                        break;
                    case QL_Number:
                        if (![value isKindOfClass:[NSNumber class]])
                            isInsertionOK = NO;
                        break;
                    case QL_Boolean:
                        if (![value isKindOfClass:[NSNumber class]])
                            isInsertionOK = NO;
                        break;
                    case QL_DateTime:
                        if (![value isKindOfClass:[NSCalendarDate class]])
                            isInsertionOK = NO;
                        break;
                    case QL_Container:
                        if (![value isKindOfClass:[NSData class]])
                            isInsertionOK = NO;
                        break;
                    case QL_RowID:
                    default:
                        if ((![value isKindOfClass:[NSNull class]]) && (![value isKindOfClass:[NSNumber class]]))
                            isInsertionOK = NO;
                        break;
                }
            }
            
            if (isInsertionOK) {
                NSString* tableAndColumn = [columns objectAtIndex:i];
                NSString* table = [QL_quickLiteDatabase QLP_prefixWithDotDelimiter:tableAndColumn];
                NSMutableDictionary* rowTableInfo = [rowInfo objectForKey:table];
                if (!rowTableInfo)
                    rowTableInfo = [[NSMutableDictionary alloc]init];
                else
                    [rowTableInfo retain];
                [rowTableInfo setObject: value forKey:tableAndColumn];
                [rowInfo setObject:rowTableInfo forKey:table];
                
                // Cleanup
                [rowTableInfo release];
            } else {
                [QL_quickLiteDatabase QLP_setLastError:[[NSString stringWithFormat:@"the value type supplied for column '%@' does not match its datatype", [columns objectAtIndex:i]]UTF8String] withID:QLP_UnknownError];
                break;
            }
        }
        
        if ([rowInfo count] == 0) {
            [rowInfo release];
            rowInfo = nil;
            isInsertionOK = NO;
        } else {
            [QL_cacheInserts addObject:rowInfo];
            [rowInfo release];
            rowInfo = nil;
        }
    }
    
    if (isInsertionOK)
        [QL_quickLiteDatabase QLP_registerModifiedCursor: self];
    
    return isInsertionOK;
}

- (BOOL)removeAllRowUIDsAtIndex:(unsigned long)rowIndex
{
    if (rowIndex >= [self rowCount])
        return NO;
    
    // Get the row info from the cache
    NSDictionary* rowInfo;
    long cacheCount = [QL_cache count];
    
    if (rowIndex < cacheCount) {
        rowInfo = [QL_cache objectAtIndex:rowIndex];
    } else {
        [QL_cacheInserts removeObjectAtIndex:(rowIndex - cacheCount)];
        return YES;
    }
    
    if (!rowInfo)
        return NO;
    
    // Extract the unique identifer
    NSString* UUID = [rowInfo objectForKey:QLP_UUID];
    if (!UUID)
        return NO;
    
    // Delete the edited info stored in QL_cacheEdits
    if (UUID)
        [QL_cacheEdits removeObjectForKey:UUID];
    
    // Find out if we have the rowUID column for the specific table
    NSArray* keys = [rowInfo allKeys];
    long i, count = [keys count];
    
    for (i = 0; i < count; i++) {
        NSString* tableColumn = [keys objectAtIndex:i];
        NSString* column = [QL_quickLiteDatabase QLP_suffixWithDotDelimiter:tableColumn];
        if ([column isEqualToString:tableColumn])
            continue;
        
        long length = [column length];
        if ([column compare:QLRecordUID options:NSCaseInsensitiveSearch range:NSMakeRange(0, length)] == NSOrderedSame) {
            // Store the key in the following format: 'address.ROWID:4'
            [QL_cacheDeletes setObject:rowInfo forKey:[NSString stringWithFormat:@"%@:%@", tableColumn, [rowInfo objectForKey:tableColumn]]];
            break;
        }
    }
    
    // Remove the object from the cache 
    [QL_cache removeObjectAtIndex:rowIndex];
    
    [QL_quickLiteDatabase QLP_registerModifiedCursor: self];
    
    return YES;
}

- (BOOL)removeAllRowUIDsAtIndexes:(NSArray*)rowIndexes
{
    NSArray *sortedArray = [rowIndexes sortedArrayUsingSelector:@selector(compare:)];
    int i, last = [sortedArray count] - 1;
    BOOL everythingIsOK = YES;
    
    for (i = last; i >= 0; --i) {
        if ([self removeAllRowUIDsAtIndex:[[sortedArray objectAtIndex:i]unsignedIntValue]] == NO)
            everythingIsOK = NO;
    }
    
    return everythingIsOK;
}

- (NSDictionary*)deletedRowUIDs
{
    NSMutableDictionary* dict = [NSMutableDictionary dictionary];
    NSEnumerator *enumerator = [QL_cacheDeletes keyEnumerator];
    NSString* key;
    
    while ((key = [enumerator nextObject])) {
        NSDictionary* rowInfo = [QL_cacheDeletes objectForKey:key];
        NSEnumerator *rowInfoEnum = [rowInfo keyEnumerator];
        NSString* tableRowUIDKey;
        while ((tableRowUIDKey = [rowInfoEnum nextObject])) {
            if (![tableRowUIDKey isEqualToString:QLP_UUID]) {
                NSNumber* rowUID = [rowInfo objectForKey:tableRowUIDKey];
                NSMutableSet* tableRowUIDSet = [dict objectForKey:tableRowUIDKey];
                if (tableRowUIDSet) {
                    [tableRowUIDSet retain];
                } else {
                    tableRowUIDSet = [[NSMutableSet alloc]init];
                }
                [tableRowUIDSet addObject:[NSNumber numberWithInt:[rowUID intValue]]];
                [dict setObject:tableRowUIDSet forKey:tableRowUIDKey];
                // Cleanup
                [tableRowUIDSet release];
            }
        }
    }
    
    return [NSDictionary dictionaryWithDictionary:dict];
}

- (NSDictionary*)modifiedRowUIDs
{
    if ([QL_cacheEdits count] == 0)
        return [NSDictionary dictionary];
    
    NSMutableDictionary* dict = [NSMutableDictionary dictionary];
    NSEnumerator *dictEnumerator = [QL_cacheEdits keyEnumerator];
    NSString* UUID;
    
    while ((UUID = [dictEnumerator nextObject])) {
        NSDictionary* rowInfo = [QL_cacheEdits objectForKey:UUID];
        NSEnumerator *rowInfoEnumerator = [rowInfo keyEnumerator];
        NSString* table;
        
        while ((table = [rowInfoEnumerator nextObject])) {
            NSNumber* rowUID = [[rowInfo objectForKey:table]objectForKey:QLRecordUID];
            if (rowUID) {
                NSMutableArray* tableRowUIDs = [dict objectForKey:table];
                if (!tableRowUIDs)
                    tableRowUIDs = [[NSMutableArray alloc]init];
                else
                    [tableRowUIDs retain];
                [tableRowUIDs addObject:rowUID];
                [dict setObject:tableRowUIDs forKey:table];
                
                // Cleanup
                [tableRowUIDs release];
            }
        }
    }
    
    return [NSDictionary dictionaryWithDictionary:dict];
}

- (unsigned long)matchingRowWithValue:(id)value forColumn:(NSString*)tableAndColumn
{
    if (![self QLP_validateValue:value forColumn:tableAndColumn startAtIndex:0])
        return NSNotFound;

    return [self QLP_matchingRowWithValue:value forColumn:tableAndColumn startAtIndex:0 comparisonMethod:NSLiteralSearch];
}

- (unsigned long)matchingRowWithValue:(id)value forColumn:(NSString*)tableAndColumn startAtIndex:(unsigned long)index
{
    if (![self QLP_validateValue:value forColumn:tableAndColumn startAtIndex:index])
        return NSNotFound;

    return [self QLP_matchingRowWithValue:value forColumn:tableAndColumn startAtIndex:index comparisonMethod:NSLiteralSearch];
}

- (unsigned long)matchingRowWithValue:(id)value forColumn:(NSString*)tableAndColumn startAtIndex:(unsigned long)index comparisonMethod:(unsigned)method
{
    if (![self QLP_validateValue:value forColumn:tableAndColumn startAtIndex:index])
        return NSNotFound;
    
    return [self QLP_matchingRowWithValue:value forColumn:tableAndColumn startAtIndex:index comparisonMethod:method];
}

- (NSArray*)matchingRowsWithValue:(id)value forColumn:(NSString*)tableAndColumn
{
    return [self matchingRowsWithValues:[NSArray arrayWithObject:value] forColumn:tableAndColumn comparisonMethod:NSLiteralSearch];
}

- (NSArray*)matchingRowsWithValue:(id)value forColumn:(NSString*)tableAndColumn comparisonMethod:(unsigned)method
{
    return [self matchingRowsWithValues:[NSArray arrayWithObject:value] forColumn:tableAndColumn comparisonMethod:method];
}

- (NSArray*)matchingRowsWithValues:(NSArray*)values forColumn:(NSString*)tableAndColumn
{
    return [self matchingRowsWithValues:values forColumn:tableAndColumn comparisonMethod:NSLiteralSearch];
}

- (NSArray*)matchingRowsWithValues:(NSArray*)values forColumn:(NSString*)tableAndColumn comparisonMethod:(unsigned)method
{
    if ((!values) || (!tableAndColumn)) {
        [QL_quickLiteDatabase QLP_setLastError:"[QuickLiteCursor matchingRowsWithValues: forColumn: setOperation: comparisonMethod:] failed: bad arguments supplied." withID: QLP_UnknownError];
        return nil;
    }

    NSMutableSet* rows = [[NSMutableSet alloc] init];
    int i, count = [values count];
    BOOL everythingWasFine = YES;
    
    if (count == 0) {
        [rows autorelease];
        return [rows allObjects];
    }
    
    // We need a non-empty set to start operating...
    [rows addObjectsFromArray:[self QLP_matchingRowsWithValue:[values objectAtIndex:0] forColumn:tableAndColumn comparisonMethod:method]];
    
    for (i = 1; i < count; i++) {
        NSArray* someRows = [self QLP_matchingRowsWithValue:[values objectAtIndex:i] forColumn:tableAndColumn comparisonMethod:method];
        if (someRows) {
            [rows unionSet:[NSSet setWithArray:someRows]];
        } else {
            everythingWasFine = NO;
            break;
        }
    }
    
    if (everythingWasFine) {
        [rows autorelease];
    } else {
        [rows release];
        rows = nil;
    }
    
    return [rows allObjects];
}

- (QuickLiteCursor*)unionCursor:(QuickLiteCursor*)cursor
{
    return [self unionCursor:cursor cacheMethod:[QL_quickLiteDatabase cacheMethod]];
}

- (QuickLiteCursor*)minusCursor:(QuickLiteCursor*)cursor
{
    return [self minusCursor:cursor cacheMethod:[QL_quickLiteDatabase cacheMethod]];
}

- (QuickLiteCursor*)intersectCursor:(QuickLiteCursor*)cursor
{
    return [self intersectCursor:cursor cacheMethod:[QL_quickLiteDatabase cacheMethod]];
}

- (QuickLiteCursor*)unionCursor:(QuickLiteCursor*)cursor cacheMethod:(QLCacheMethod)cacheMethod
{
    NSDictionary *datatypes = [self QLP_verifyCursorsForSetOperation:cursor];
    if (!datatypes)
        return nil;
    
    // Get all ROWUIDs in one collection
    NSString *table = [[self tables] objectAtIndex:0];
    NSMutableSet *rowuidsA = [NSMutableSet setWithArray:[self valuesForColumn:[NSString stringWithFormat:@"%@.%@", table, QLRecordUID]]];
    NSSet *rowuidsB = [NSSet setWithArray:[cursor valuesForColumn:[NSString stringWithFormat:@"%@.%@", table, QLRecordUID]]];
    [rowuidsA unionSet:rowuidsB];
    
    // Check to see if we have positives
    if ([rowuidsA count] == 0) {
        // Fake an empty cursor...
        return [QL_quickLiteDatabase performQuery:[NSString stringWithFormat:@"SELECT * FROM %@ WHERE %@.%@ = '-1';", table, table, QLRecordUID] cacheMethod:cacheMethod];
    }
    
    // Append the rowuids to a long string and execute the query
    NSMutableString* sqlQuery = [[NSMutableString alloc]initWithFormat:@"SELECT "];
    [QL_quickLiteDatabase QLP_sqlString:sqlQuery appendingTags:[datatypes allKeys]];
    [sqlQuery appendString:[NSString stringWithFormat:@" FROM %@ WHERE %@ IN (", table, [NSString stringWithFormat:@"%@.%@", table, QLRecordUID]]];
    [QL_quickLiteDatabase QLP_sqlString:sqlQuery appendingTags:[rowuidsA allObjects]];
    [sqlQuery appendString:[NSString stringWithFormat:@");"]];
    QuickLiteCursor* resultCursor = [QL_quickLiteDatabase performQuery:sqlQuery cacheMethod:cacheMethod];
    [sqlQuery release];
    
    // We can return the result cursor now...
    return resultCursor;
}

- (QuickLiteCursor*)minusCursor:(QuickLiteCursor*)cursor cacheMethod:(QLCacheMethod)cacheMethod
{
    NSDictionary *datatypes = [self QLP_verifyCursorsForSetOperation:cursor];
    if (!datatypes)
        return nil;
    
    // Get all ROWUIDs in one collection
    NSString *table = [[self tables] objectAtIndex:0];
    NSMutableSet *rowuidsA = [NSMutableSet setWithArray:[self valuesForColumn:[NSString stringWithFormat:@"%@.%@", table, QLRecordUID]]];
    NSSet *rowuidsB = [NSSet setWithArray:[cursor valuesForColumn:[NSString stringWithFormat:@"%@.%@", table, QLRecordUID]]];
    [rowuidsA minusSet:rowuidsB];
    
    // Check to see if we have positives
    if ([rowuidsA count] == 0) {
        // Fake an empty cursor...
        return [QL_quickLiteDatabase performQuery:[NSString stringWithFormat:@"SELECT * FROM %@ WHERE %@.%@ = '-1';", table, table, QLRecordUID] cacheMethod:cacheMethod];
    }
    
    // Append the rowuids to a long string and execute the query
    NSMutableString* sqlQuery = [[NSMutableString alloc]initWithFormat:@"SELECT "];
    [QL_quickLiteDatabase QLP_sqlString:sqlQuery appendingTags:[datatypes allKeys]];
    [sqlQuery appendString:[NSString stringWithFormat:@" FROM %@ WHERE %@ IN (", table, [NSString stringWithFormat:@"%@.%@", table, QLRecordUID]]];
    [QL_quickLiteDatabase QLP_sqlString:sqlQuery appendingTags:[rowuidsA allObjects]];
    [sqlQuery appendString:[NSString stringWithFormat:@");"]];
    QuickLiteCursor* resultCursor = [QL_quickLiteDatabase performQuery:sqlQuery cacheMethod:cacheMethod];
    [sqlQuery release];
    
    // We can return the result cursor now...
    return resultCursor;
}

- (QuickLiteCursor*)intersectCursor:(QuickLiteCursor*)cursor cacheMethod:(QLCacheMethod)cacheMethod
{
    NSDictionary *datatypes = [self QLP_verifyCursorsForSetOperation:cursor];
    if (!datatypes)
        return nil;
    
    // Get all ROWUIDs in one collection
    NSString *table = [[self tables] objectAtIndex:0];
    NSMutableSet *rowuidsA = [NSMutableSet setWithArray:[self valuesForColumn:[NSString stringWithFormat:@"%@.%@", table, QLRecordUID]]];
    NSSet *rowuidsB = [NSSet setWithArray:[cursor valuesForColumn:[NSString stringWithFormat:@"%@.%@", table, QLRecordUID]]];
    [rowuidsA intersectSet:rowuidsB];
    
    // Check to see if we have positives
    if ([rowuidsA count] == 0) {
        // Fake an empty cursor...
        return [QL_quickLiteDatabase performQuery:[NSString stringWithFormat:@"SELECT * FROM %@ WHERE %@.%@ = '-1';", table, table, QLRecordUID] cacheMethod:cacheMethod];
    }
    
    // Append the rowuids to a long string and execute the query
    NSMutableString* sqlQuery = [[NSMutableString alloc]initWithFormat:@"SELECT "];
    [QL_quickLiteDatabase QLP_sqlString:sqlQuery appendingTags:[datatypes allKeys]];
    [sqlQuery appendString:[NSString stringWithFormat:@" FROM %@ WHERE %@ IN (", table, [NSString stringWithFormat:@"%@.%@", table, QLRecordUID]]];
    [QL_quickLiteDatabase QLP_sqlString:sqlQuery appendingTags:[rowuidsA allObjects]];
    [sqlQuery appendString:[NSString stringWithFormat:@");"]];
    QuickLiteCursor* resultCursor = [QL_quickLiteDatabase performQuery:sqlQuery cacheMethod:cacheMethod];
    [sqlQuery release];
    
    // We can return the result cursor now...
    return resultCursor;
}

#pragma mark// ==================================
#pragma mark// Cursor Methods (private)
#pragma mark// ==================================

- (BOOL)QLP_setupCursor
{
    [QL_cache removeAllObjects];
    
    const char *query = [QL_sqlQuery UTF8String];
    BOOL everythingOK = YES;
    
    // Make sure we obtain full column names
    [QL_quickLiteDatabase QLP_setFullColumnNamesEnabled];
    
    // Prepare the VM
    int result = sqlite3_prepare([QL_quickLiteDatabase QLP_sqliteDatabase], query, strlen(query), &QL_sqliteVM, &query);
    if (result != QLSuccess) {
        const char* errMsg = sqlite3_errmsg([QL_quickLiteDatabase QLP_sqliteDatabase]);
        [QL_quickLiteDatabase QLP_logIfInDebugMode:[NSString stringWithUTF8String:errMsg]];
        [QL_quickLiteDatabase QLP_setLastError:errMsg withID: result];
        everythingOK = NO;
    }
    
    if (everythingOK) {
        // Cache the columns
        if (![self QLP_cacheCursorColumns])
            everythingOK = NO;
        
        if ([[self tables]count] == 0)
            QL_cacheMethod = CacheAllData;
        
        if ((everythingOK) && ([QL_cacheColumns count] > 0)) {
            // Cache the data (if needed)
            if(QL_cacheMethod != CacheAllData) {
                NSEnumerator *enumerator = [QL_cacheTables objectEnumerator];
                NSString* table;
                NSString* rowUIDTableColumn = nil;
                
                while ((table = [enumerator nextObject])) {
                    rowUIDTableColumn = [NSString stringWithFormat:@"%@.%@", table, QLRecordUID];
                    BOOL foundRowUID = [QL_cacheColumns containsObject:rowUIDTableColumn];
                    
                    if (!foundRowUID) {
                        // Since there is no rowUID in sight, we cannot use QuickEdit and we must
                        // enforce data caching, just to be safe.
                        rowUIDTableColumn = nil;
                        QL_cacheMethod = CacheAllData;
                        break;
                    }
                }
            }
            
            [self QLP_cacheCursorDataTreatingValuesAsString:QL_treatAsString];
        }
        
        result = sqlite3_finalize(QL_sqliteVM);
        if (result != QLSuccess) {
            const char* errMsg = sqlite3_errmsg([QL_quickLiteDatabase QLP_sqliteDatabase]);
            [QL_quickLiteDatabase QLP_logIfInDebugMode:[NSString stringWithUTF8String:errMsg]];
            [QL_quickLiteDatabase QLP_setLastError:errMsg withID: result];
            everythingOK = NO;
        } else {
            [QL_quickLiteDatabase QLP_setLastError: NULL withID: QLSuccess];
        }
    }
    
    QL_sqliteVM = NULL;
    
    return everythingOK;
}

- (BOOL)QLP_cacheCursorColumns
{
    int result = sqlite3_reset(QL_sqliteVM);
    if (result != QLSuccess) {
        [QL_quickLiteDatabase QLP_setLastError: sqlite3_errmsg([QL_quickLiteDatabase QLP_sqliteDatabase]) withID: result];
        return NO;
    }
    
    [QL_cacheTables release];
    QL_cacheTables = nil;
    
    [QL_cacheColumns release];
    QL_cacheColumns = nil;
    
    // Let's get the columns: obtain the first row
    BOOL allColumnsAccountedFor = YES;
    BOOL waitingForRow = YES;
    
    do {
        BOOL dataIsReady = NO;
        const char* errMsg = NULL;
        
        result = sqlite3_step(QL_sqliteVM);
        
        switch (result) {
            case SQLITE_BUSY:
                break;
            case SQLITE_OK:
            case SQLITE_DONE:
                dataIsReady = YES;
                waitingForRow = NO;
                break;
            case SQLITE_ROW:
                dataIsReady = YES;
                waitingForRow = NO;
                break;
            default:
                errMsg = sqlite3_errmsg([QL_quickLiteDatabase QLP_sqliteDatabase]);
                [QL_quickLiteDatabase QLP_logIfInDebugMode:[NSString stringWithUTF8String:errMsg]];
                [QL_quickLiteDatabase QLP_setLastError:errMsg withID: result];
                waitingForRow = NO;
                break;
        }
        
        if (dataIsReady) {
            // Cache the columns found in the cursor
            NSMutableSet* tempColumns = [[NSMutableSet alloc]init];
            NSMutableSet* tempTables = [[NSMutableSet alloc]init];
            int i, numColumns = sqlite3_column_count(QL_sqliteVM);
            
            for (i = 0; i < numColumns; i++) {
                const char* columnCStr = sqlite3_column_name(QL_sqliteVM, i);
                if (columnCStr != NULL) {
                    NSString* column = [NSString stringWithUTF8String:columnCStr];
                    if (column) {
                        [tempColumns addObject:column];
                        NSString* table = [QL_quickLiteDatabase QLP_prefixWithDotDelimiter:column];
                        [tempTables addObject:table];
                    }
                } else {
                    allColumnsAccountedFor = NO;
                    break;
                }
            }
            
            // Make an immutable copy, so other users cannot mess with its contents...
            if (allColumnsAccountedFor) {
                QL_cacheColumns = [[NSSet alloc]initWithSet:tempColumns];
                QL_cacheTables = [[NSSet alloc]initWithSet:tempTables];
            }
            
            // Cleanup
            [tempColumns release];
            [tempTables release];
        }
    } while (waitingForRow);
    
    if (!QL_cacheTables)
        QL_cacheTables = [[NSSet alloc]init];
    
    if (!QL_cacheColumns)
        QL_cacheColumns = [[NSSet alloc]init];
				
    return allColumnsAccountedFor;
}

- (BOOL)QLP_cacheCursorDataTreatingValuesAsString:(BOOL)treatAsString
{
    int result = sqlite3_reset(QL_sqliteVM);
    if (result != QLSuccess) {
        const char* errMsg = sqlite3_errmsg([QL_quickLiteDatabase QLP_sqliteDatabase]);
        [QL_quickLiteDatabase QLP_logIfInDebugMode:[NSString stringWithUTF8String:errMsg]];
        [QL_quickLiteDatabase QLP_setLastError:errMsg withID: result];
        return NO;
    }
    
    BOOL allCursorTraversed = NO;
    BOOL errorWhileTraversingOccurred = NO;
    int i, numColumns = sqlite3_column_count(QL_sqliteVM), iterationsCount = 0;
    
    do {
        BOOL dataIsReady = NO;
        const char* errMsg = NULL;
        
        result = sqlite3_step(QL_sqliteVM);
        
        switch (result) {
            case SQLITE_BUSY:
                break;
            case SQLITE_OK:
            case SQLITE_DONE:
                allCursorTraversed = YES;
                break;
            case SQLITE_ROW:
                iterationsCount++;
                dataIsReady = YES;
                break;
            default:
                errMsg = sqlite3_errmsg([QL_quickLiteDatabase QLP_sqliteDatabase]);
                [QL_quickLiteDatabase QLP_logIfInDebugMode:[NSString stringWithUTF8String:errMsg]];
                [QL_quickLiteDatabase QLP_setLastError:errMsg withID: result];
                allCursorTraversed = YES;
                errorWhileTraversingOccurred = YES;
                break;
        }
        
        if (dataIsReady) {
            NSMutableDictionary* values = [[NSMutableDictionary alloc] init];
            
            for (i = 0; i < numColumns; i++) {
                const char* tableAndColumnCStr = sqlite3_column_name(QL_sqliteVM, i);
                
                if (!tableAndColumnCStr) {
                    errorWhileTraversingOccurred = YES;
                    break;
                }
                
                const unsigned char* columnData = sqlite3_column_text(QL_sqliteVM, i);
                NSString* tableAndColumn = [[NSString alloc]initWithUTF8String:tableAndColumnCStr];
                id value = nil;
                BOOL cacheDataElement = NO;
                
                if ([[QL_quickLiteDatabase QLP_suffixWithDotDelimiter:tableAndColumn]isEqualToString:QLRecordUID]) {
                    if (!columnData) {
                        errorWhileTraversingOccurred = YES;
                        // Cleanup...
                        [tableAndColumn release];
                        break;
                    } else {
                        NSString *UUID = [QuickLiteDatabase UUIDString];
                        [values setObject:UUID forKey:QLP_UUID];
                        cacheDataElement = YES;
                    }
                }
                
                switch (QL_cacheMethod) {
                    case DoNotCacheData:
                    case CacheDataOnDemand:
                        // No need to do anything...
                        break;
                    case CacheAllData:
                        cacheDataElement = YES;
                        break;
                    default:
                        errorWhileTraversingOccurred = YES;
                }
                
                if (cacheDataElement) {
                    if (columnData) {
                        if (!value) {
                            if (treatAsString) {
                                value = [[NSString alloc]initWithUTF8String:(const char*)columnData];
                            } else {
                                value = [[self QLP_objectFromSQLiteData:(const char*)columnData withColumn:tableAndColumn]retain];
                            }
                        }
                    } else {
                        value = [[NSNull null]retain];
                    }
                    
                    if (value) {
                        [values setObject:value forKey:tableAndColumn];
                    }
                }
                
                // Cleanup...
                [value release];
                [tableAndColumn release];
            }
            
            if (errorWhileTraversingOccurred == NO)
                [QL_cache addObject:values];
            
            // Cleanup
            [values release];
        }
    } while (!allCursorTraversed);
    
    if (errorWhileTraversingOccurred) {
        [QL_cache removeAllObjects];
    }
    
    return (errorWhileTraversingOccurred == NO);
}

- (BOOL)QLP_setValue:(id)value forColumn:(NSString*)tableAndColumn forRow:(unsigned long)rowIndex
{
    long count = [self rowCount];
    if (count == 0) {
        [QL_quickLiteDatabase QLP_setLastError:"[QuickLiteCursor setValue:forColumn:] failed: (count == 0)" withID: QLP_UnknownError];
        return NO;
    }
    
    if (rowIndex >= count) {
        [QL_quickLiteDatabase QLP_setLastError:"[QuickLiteCursor setValue:forColumn:] failed: (rowIndex >= count)" withID: QLP_UnknownError];
        return NO;
    }

    NSArray* cursorColumns = [self columns];
    if (![cursorColumns containsObject:tableAndColumn]) {
        [QL_quickLiteDatabase QLP_setLastError:[[NSString stringWithFormat:@"[QuickLiteCursor setValue:forColumn:] failed: column '%@' not found in the cursor.", tableAndColumn]UTF8String] withID: QLP_UnknownError];
        return NO;
    }

    NSString* tableName = [QL_quickLiteDatabase QLP_prefixWithDotDelimiter:tableAndColumn];
    if ([tableName isEqualToString:tableAndColumn]) {
        [QL_quickLiteDatabase QLP_setLastError:[[NSString stringWithFormat:@"[QuickLiteCursor setValue:forColumn:] failed: tableAndColumn malformed (could not obtain the table name from '%@').", tableAndColumn]UTF8String] withID: QLP_UnknownError];
        return NO;
    }

    NSString* column = [QL_quickLiteDatabase QLP_suffixWithDotDelimiter:tableAndColumn];
    if ([column isEqualToString:tableAndColumn]) {
        [QL_quickLiteDatabase QLP_setLastError:[[NSString stringWithFormat:@"[QuickLiteCursor setValue:forColumn:] failed: tableAndColumn malformed (could not obtain the column name from '%@').", tableAndColumn]UTF8String] withID: QLP_UnknownError];
        return NO;
    }

    // Make sure we don't pass a ROWUID-type column
    NSArray* reservedRowUIDs = [QuickLiteDatabase sharedROWIDKeywords];
    if ([reservedRowUIDs containsObject:column]) {
        [QL_quickLiteDatabase QLP_setLastError:"[QuickLiteCursor setValue:forColumn:] failed: ROWID column cannot be modified." withID: QLP_UnknownError];
        return NO;
    }

    BOOL valueIsAKeeper = NO;
    
    QLDatatype columnDatatype = [QL_quickLiteDatabase QLP_datatypeForTable:tableName column:column];
    
    if ([value isKindOfClass:[NSNull class]] == NO) {
        switch (columnDatatype) {
            case QL_String:
                if ([value isKindOfClass:[NSString class]])
                    valueIsAKeeper = YES;
                break;
            case QL_Number:
                if ([value isKindOfClass:[NSNumber class]])
                    valueIsAKeeper = YES;
                break;
            case QL_Boolean:
                if ([value isKindOfClass:[NSNumber class]]) {
                    valueIsAKeeper = YES;
                }
                break;
            case QL_DateTime:
                if ([value isKindOfClass:[NSCalendarDate class]]) {
                    valueIsAKeeper = YES;
                }
                break;
            case QL_Container:
                if ([value isKindOfClass:[NSData class]])
                    valueIsAKeeper = YES;
                break;
            case QL_RowID:
            default:
                // No need to do anything. We won't cache the data.
                break;
        }
    } else {
        valueIsAKeeper = (columnDatatype != QL_RowID);
    }
    
    if (valueIsAKeeper) {
        NSMutableDictionary* cacheInfo = nil;

        // First find out if we have the rowUID column for the specific table
        NSString* rowUIDColumn = [self QLP_rowIDColumnForColumn:tableAndColumn];
        
        if (!rowUIDColumn) {
            if ((rowIndex - [QL_cache count] >= 0) && ([cacheInfo count] > 0)) {
                // Perhaps the data belongs to the insert cache...
                cacheInfo = [QL_cacheInserts objectAtIndex:(rowIndex - [QL_cache count])];
                // Now get the value for the given table
                NSMutableDictionary* rowTableInfo = [cacheInfo objectForKey:tableName];
                if (rowTableInfo) {
                    [rowTableInfo setObject:value forKey:tableAndColumn];
                    [cacheInfo setObject:rowTableInfo forKey:tableName];
                } else {
                    [QL_quickLiteDatabase QLP_setLastError:[[NSString stringWithFormat:@"[QuickLiteCursor setValue:forColumn:] failed: rowTableInfo not found for table '%@'.", tableName]UTF8String] withID: QLP_UnknownError];
                    return NO;
                }
            } else {
                [QL_quickLiteDatabase QLP_setLastError:[[NSString stringWithFormat:@"[QuickLiteCursor setValue:forColumn:] failed: ROWID column not found for table '%@'.", tableName]UTF8String] withID: QLP_UnknownError];
                return NO;
            }
        } else {
            // Get the contents of the array at the specified index
            cacheInfo = [QL_cache objectAtIndex:rowIndex];
            if (cacheInfo) {
                NSNumber* rowUID = [cacheInfo objectForKey:rowUIDColumn];
                if (!rowUID) {
                    [QL_quickLiteDatabase QLP_setLastError:[[NSString stringWithFormat:@"[QuickLiteCursor setValue:forColumn:] failed: ROWID value not found for row '%ld'.", rowIndex]UTF8String] withID: QLP_UnknownError];
                    return NO;
                }
            
                // Now retrieve the UUID to gain access to QL_cacheEdits
                NSString* UUID = [cacheInfo objectForKey:QLP_UUID];
                if (!UUID) {
                    [QL_quickLiteDatabase QLP_setLastError:[[NSString stringWithFormat:@"[QuickLiteCursor setValue:forColumn:] failed: UUID value not found for row '%ld'.", rowIndex]UTF8String] withID: QLP_UnknownError];
                    return NO;
                }
            
                NSMutableDictionary* rowInfo = [QL_cacheEdits objectForKey:UUID];
                if (!rowInfo)
                    rowInfo = [[NSMutableDictionary alloc]init];
                else
                    [rowInfo retain];
                NSMutableDictionary* rowTableInfo = [rowInfo objectForKey:tableName];
                if (!rowTableInfo)
                    rowTableInfo = [[NSMutableDictionary alloc]init];
                else
                    [rowTableInfo retain];
                
                [rowTableInfo setObject:value forKey:tableAndColumn];
                [rowTableInfo setObject:UUID forKey:QLP_UUID];
                [rowTableInfo setObject:rowUID forKey:QLRecordUID];
                [rowInfo setObject:rowTableInfo forKey:tableName];
                [QL_cacheEdits setObject:rowInfo forKey:UUID];
                
                // Cleanup
                [rowInfo release];
            }
        }
        [QL_quickLiteDatabase QLP_registerModifiedCursor: self];
    } else {
        [QL_quickLiteDatabase QLP_setLastError:[[NSString stringWithFormat:@"the value type supplied for column '%@' does not match its datatype", tableAndColumn]UTF8String] withID:QLP_UnknownError];   
    }
    
    return valueIsAKeeper;
}

- (NSString*)QLP_stringForColumn:(NSString*)tableAndColumn andRow:(unsigned long)rowIndex
{
    return [self QLP_valueForColumn:tableAndColumn andRow:rowIndex treatValuesAsString:YES];
}

- (id)QLP_valueForColumn:(NSString*)tableAndColumn andRow:(unsigned long)rowIndex treatValuesAsString:(BOOL)flag
{
    if (rowIndex >= [self rowCount])
        return nil;
    
    NSString* table = [QL_quickLiteDatabase QLP_prefixWithDotDelimiter:tableAndColumn];
    
    // Get the row info from the cache
    NSDictionary* cacheInfo = nil;
    id value = nil;
    long cacheCount = [QL_cache count];
    
    if (rowIndex < cacheCount) {
        cacheInfo = [QL_cache objectAtIndex:rowIndex];
        // Second, try to see if the value is in QL_cacheEdits
        // Get the contents of the array at the specified index
        if (cacheInfo) {
            // Now retrieve the UUID to gain access to QL_cacheEdits
            NSString* UUID = [cacheInfo objectForKey:QLP_UUID];
            if (UUID) {
                NSDictionary* rowInfo = [QL_cacheEdits objectForKey:UUID];
                if (rowInfo) {
                    // Now get the value for the given table
                    NSDictionary* rowTableInfo = [rowInfo objectForKey:table];
                    if (rowTableInfo) {
                        value = [rowTableInfo objectForKey:tableAndColumn];
                        if (value) {
                            if (flag) {
                                return [QL_quickLiteDatabase descriptionForValue:value];
                            } else {
                                return value;
                            }
                        }
                    }
                }
            }
        }
    } else {
        cacheInfo = [QL_cacheInserts objectAtIndex:(rowIndex - cacheCount)];
        // Now get the value for the given table
        NSDictionary* rowTableInfo = [cacheInfo objectForKey:table];
        if (rowTableInfo) {
            value = [rowTableInfo objectForKey:tableAndColumn];
            if (value) {
                if (flag)
                    return [QL_quickLiteDatabase descriptionForValue:value];
                return value;
            }
        }
    }
    
    
    // Third, try to retrieve the info directly from the cache
    NSDictionary* rowInfo = [QL_cache objectAtIndex:rowIndex];
    if (rowInfo) {
        id value = [rowInfo objectForKey:tableAndColumn];
        if (value) {
            if (flag)
                return [QL_quickLiteDatabase descriptionForValue:value];
            return value;
        }
    }
    
    // Fourth, check to see if we have the rowUID cached
    NSString* rowUIDValue = [self QLP_rowUIDInfoOfColumn:tableAndColumn forRow:rowIndex];
    if (!rowUIDValue)
        return nil;
    
    NSString* rowUIDTableColumn = [[NSString alloc]initWithFormat:@"%@.%@", table, QLRecordUID];
    
    NSString* sqlQuery = [[NSString alloc]initWithFormat:@"SELECT %@ FROM %@ WHERE %@ = '%@';", tableAndColumn, table, rowUIDTableColumn, rowUIDValue];
    QuickLiteCursor* cursor = [QL_quickLiteDatabase QLP_performInternalQuickLiteQuery:sqlQuery cacheMethod:CacheAllData treatValuesAsString:flag];
    
    // Cleanup...
    [sqlQuery release];
    [rowUIDTableColumn release];
    
    // The cursor could be nil because the database is already closed: bail out
    if (!cursor)
        return nil;
    
    value = [cursor QLP_valueFromCache:tableAndColumn];
    
    if (!value)
        value = [NSNull null];
    
    if (QL_cacheMethod == CacheDataOnDemand) {
        NSMutableDictionary* rowInfo = [QL_cache objectAtIndex: rowIndex];
        if (!rowInfo)
            rowInfo = [[NSMutableDictionary alloc]init];
        else
            [rowInfo retain];
        [rowInfo setObject:value forKey:tableAndColumn];
        [QL_cache replaceObjectAtIndex:rowIndex withObject:rowInfo];
        [rowInfo release];
    }
    
    if (flag)
        return [QL_quickLiteDatabase descriptionForValue:value];
    
    return value;
}

- (id)QLP_valueFromCache:(NSString*)tableAndColumn
{
    if ([QL_cache count] > 0)
        return [[QL_cache objectAtIndex:0]objectForKey:tableAndColumn];
    
    return nil;
}

- (void)QLP_initializeVM:(sqlite3_stmt**)sqliteVM withTableColumn:(NSString*)tableAndColumn andRow:(unsigned long)rowIndex
{
    *sqliteVM = NULL;
    
    if (QL_cacheMethod == DoNotCacheData) {
        NSString* table = [QL_quickLiteDatabase QLP_prefixWithDotDelimiter:tableAndColumn];
        NSString* rowUIDTableColumn = [[NSString alloc]initWithFormat:@"%@.%@", table, QLRecordUID];
        NSString* rowUIDValue = [self QLP_rowUIDInfoOfColumn:tableAndColumn forRow:rowIndex];
        const char *query_tail = [[NSString stringWithFormat:@"SELECT %@ FROM %@ WHERE %@ = '%@';", tableAndColumn, table, rowUIDTableColumn, rowUIDValue] UTF8String];
        int result = sqlite3_prepare([QL_quickLiteDatabase QLP_sqliteDatabase], query_tail, -1, sqliteVM, &query_tail);
        
        if (result == QLSuccess) {
            BOOL continueTrying = YES;
            BOOL dataIsReady = NO;
            
            do {
                result = sqlite3_step(*sqliteVM);
                
                switch (result) {
                    case SQLITE_OK:
                    case SQLITE_DONE:
                    case SQLITE_ROW:
                        dataIsReady = YES;
                        continueTrying = NO;
                        break;
                    case SQLITE_BUSY:
                        sqlite3_reset(*sqliteVM);
                        continueTrying = YES;
                        break;
                    default:
                        continueTrying = NO;
                        break;
                }
            } while (continueTrying);
            
            if (!dataIsReady) {
                sqlite3_finalize(*sqliteVM);
                *sqliteVM = NULL;
                [QL_quickLiteDatabase QLP_setLastError:"QuickLite:cannot retrieve the int value because stepping through the query failed." withID:QLP_UnknownError];
            }
        } else {
            *sqliteVM = NULL;
            [QL_quickLiteDatabase QLP_setLastError:"QuickLite:cannot retrieve the int value because preparing the query failed." withID:QLP_UnknownError];
        }
    }
}

- (NSString*)QLP_rowUIDInfoOfColumn:(NSString*)tableAndColumn forRow:(unsigned long)rowIndex
{
    // Enforce proper tableAndColumn naming
    NSRange range = [tableAndColumn rangeOfString:@"."];
    if (range.location == NSNotFound)
        return nil;
    
    NSString* table = [QL_quickLiteDatabase QLP_prefixWithDotDelimiter:tableAndColumn];
    if ([table isEqualToString:tableAndColumn])
        return nil;
    
    NSString* rowUIDTableColumn = [[NSString alloc]initWithFormat:@"%@.%@", table, QLRecordUID];
    NSString* value = [[QL_cache objectAtIndex:rowIndex]objectForKey:rowUIDTableColumn];
    
    // Cleanup...
    [rowUIDTableColumn release];
    
    return value;
}

- (NSString*)QLP_rowIDColumnForTable:(NSString*)table
{
    if (!table)
        return nil;
    
    NSString* rowIDColumn = [[NSString alloc]initWithFormat:@"%@.%@", table, QLRecordUID];
    
    // Attempt to retrieve the column...
    NSEnumerator *enumerator = [QL_cacheColumns objectEnumerator];
    unsigned long length = [rowIDColumn length];
    NSString* key = nil;
    BOOL foundIt = NO;
    
    while ((key = [enumerator nextObject])) {
        if ([key compare:rowIDColumn options:NSCaseInsensitiveSearch range:NSMakeRange(0, length)] == NSOrderedSame) {
            foundIt = YES;
            break;
        }
    }
    
    if (!foundIt)
        key = nil;
    
    // Cleanup
    [rowIDColumn release];
    
    return key;
}

- (NSString*)QLP_rowIDColumnForColumn:(NSString*)tableAndColumn
{
    if (!tableAndColumn)
        return nil;
    
    NSString* rowIDColumn = [[NSString alloc]initWithFormat:@"%@.%@", [QL_quickLiteDatabase QLP_prefixWithDotDelimiter:tableAndColumn], QLRecordUID];
    
    // Attempt to retrieve the column...
    unsigned long length = [rowIDColumn length];
    NSEnumerator *enumerator = [QL_cacheColumns objectEnumerator];
    NSString* key = nil;
    BOOL foundIt = NO;
    
    while ((key = [enumerator nextObject])) {
        if ([key compare:rowIDColumn options:NSCaseInsensitiveSearch range:NSMakeRange(0, length)] == NSOrderedSame) {
            foundIt = YES;
            break;
        }
    }
    
    if (!foundIt)
        key = nil;
    
    // Cleanup
    [rowIDColumn release];
    
    return key;
}

- (BOOL)QLP_buildAndExecuteUpdateQueryWithRowID:(NSNumber*)rowUID withColumns:(NSArray*)columns andValues:(NSArray*)values forTable:(NSString*)table
{
    if (!rowUID)
        return NO;
    
    if (!table)
        return NO;
    
    BOOL isTransactionOK = YES;
    int i, count = [columns count];
    
    for (i = 0; i < count; i++) {
        // Skip the UUID element...
        NSString* tableAndColumnName = [columns objectAtIndex: i];
        NSString* column = [QL_quickLiteDatabase QLP_suffixWithDotDelimiter:tableAndColumnName];
        
        if ([column isEqualToString:tableAndColumnName])
            if (([column isEqualToString:QLP_UUID]) || ([column isEqualToString:QLRecordUID]))
                continue;
            else
                if (([tableAndColumnName isEqualToString:QLP_UUID]) || ([tableAndColumnName isEqualToString:QLRecordUID]))
                    continue;
        
        // Some variables we'll need...
        NSString* dateStr = nil;
        NSTimeInterval interval;
        NSCalendarDate *newDate = nil;
        int boolNumber = 0;
        NSString* sqlQuery = nil;
        NSString* rowUIDTableColumn = [[NSString alloc]initWithFormat:@"%@.%@", table, QLRecordUID];
        
        // Obtain the value
        id value = [values objectAtIndex: i];
        
        if (value != [NSNull null]) {
            // Obtain the datatype
            QLDatatype columnDatatype = [QL_quickLiteDatabase QLP_datatypeForTable:table column:column];
            
            switch (columnDatatype) {
                case QL_String:
                    sqlQuery = [[NSString alloc]initWithFormat:@"UPDATE %@ SET %@ = '%@' WHERE %@ = '%@';", table, column, value, rowUIDTableColumn, rowUID];
                    break;
                case QL_Number:
                    sqlQuery = [[NSString alloc]initWithFormat:@"UPDATE %@ SET %@ = '%@' WHERE %@ = '%@';", table, column, [value stringValue], rowUIDTableColumn, rowUID];
                    break;
                case QL_Boolean:
                    if ([value boolValue])
                        boolNumber = 1;
                    sqlQuery = [[NSString alloc]initWithFormat:@"UPDATE %@ SET %@ = '%d' WHERE %@ = '%@';", table, column, boolNumber, rowUIDTableColumn, rowUID];
                    break;
                case QL_DateTime:
                    dateStr = [value descriptionWithCalendarFormat:nil timeZone:nil locale:nil];
                    newDate = [NSCalendarDate dateWithString: dateStr];
                    interval = fabs([value timeIntervalSinceDate:newDate]);
                    dateStr = [NSString stringWithFormat:@"%@:%g", dateStr, interval];
                    sqlQuery = [[NSString alloc]initWithFormat:@"UPDATE %@ SET %@ = '%@' WHERE %@ = '%@';", table, column, dateStr, rowUIDTableColumn, rowUID];
                    break;
                case QL_Container:
                    // Encode the BLOB in a way SQLite v3 understands: enclosed within X'<my real BLOB data>'...
                    sqlQuery = [[NSString alloc]initWithFormat:@"UPDATE %@ SET %@ = '%@' WHERE %@ = '%@';", table, column, [QuickLiteDatabase prepareStringForQuery:[NSString stringWithFormat:@"X'%@'", [QL_quickLiteDatabase encodeDataToBase64:value]]], rowUIDTableColumn, 
                        rowUID];
                    break;
                default:
                    // Unknown data type: let's bail out
                    break;
            }
        } else {
            sqlQuery = [[NSString alloc]initWithFormat:@"UPDATE %@ SET %@ = NULL WHERE %@ = '%@';", table, column, rowUIDTableColumn, rowUID];
        }
        
        if (sqlQuery) {
            isTransactionOK = [QL_quickLiteDatabase QLP_performExecuteQuery:sqlQuery];
        } else {
            isTransactionOK = NO;
        }
        
        // Cleanup
        [sqlQuery release];
        [rowUIDTableColumn release];
    }
    
    return isTransactionOK;
}

- (BOOL)QLP_saveAndDeregisterCursor:(BOOL)doDeregisterCursor
{
    NSEnumerator *_cacheEditsEnumerator = [QL_cacheEdits keyEnumerator];
    NSString* rowUIDStringKey;
    BOOL isTransactionOK = YES;
    
    BOOL transactionSetHere = NO;
    if ([QL_quickLiteDatabase isTransactionActive] == NO)
        transactionSetHere = [QL_quickLiteDatabase beginTransaction];
    
    // Save the edits
    while ((rowUIDStringKey = [_cacheEditsEnumerator nextObject])) {
        NSDictionary* rowInfoDict = [QL_cacheEdits objectForKey:rowUIDStringKey];
        NSEnumerator *rowInfoDictEnumerator = [rowInfoDict keyEnumerator];
        NSString* tableKey;
        
        while ((tableKey = [rowInfoDictEnumerator nextObject])) {
            NSDictionary* tableChanges = [rowInfoDict objectForKey:tableKey];
            if (tableChanges) {
                NSNumber* rowUID = [tableChanges objectForKey:QLRecordUID];
                if (!rowUID) {
                    [QL_quickLiteDatabase QLP_setLastError:"Cannot save the edits for the cursor because the rowUID cannot be found." withID:QLP_UnknownError];
                    isTransactionOK = NO;
                    break;
                }
                NSArray* columns = [tableChanges allKeys];
                NSArray* values = [tableChanges allValues];
                if ([columns count]) {
                    // Build the query and execute it
                    if (![self QLP_buildAndExecuteUpdateQueryWithRowID:rowUID withColumns:columns andValues:values forTable:tableKey]) {
                        isTransactionOK = NO;
                        break;
                    }
                }
            }
        }
        
        if (!isTransactionOK)
            break;
    }
    
    // Save the inserts
    if (isTransactionOK) {
        long i, cacheCount = [QL_cacheInserts count];
        
        for (i = 0; i < cacheCount; i++) {
            NSDictionary* cacheInfo = [QL_cacheInserts objectAtIndex:i];
            NSEnumerator *enumerator = [cacheInfo keyEnumerator];
            NSString* table;
            
            while ((table = [enumerator nextObject])) {
                NSDictionary* tableInfo = [cacheInfo objectForKey:table];
                NSArray* values = [tableInfo allValues];
                NSArray* columns = [tableInfo allKeys];
                
                // Some sanity check
                if (([values count] == 0) || ([columns count] == 0)) {
                    [QL_quickLiteDatabase QLP_setLastError:"Cannot save the inserts for the cursor because of value/columns count mismatch." withID:QLP_UnknownError];
                    isTransactionOK = NO;
                    break;
                }
                
                // [QuickLiteDatabase insertValues] only needs the column.
                NSMutableArray* tableAndColumns = [NSMutableArray array];
                long j, columnsCount = [columns count];
                
                for (j = 0; j < columnsCount; j++) {
                    // Extract the column only...
                    NSString* column = [QL_quickLiteDatabase QLP_suffixWithDotDelimiter:[columns objectAtIndex:j]];
                    if ([column isEqualToString:[columns objectAtIndex:j]]) {
                        [QL_quickLiteDatabase QLP_setLastError:"Cannot save the inserts for the cursor because the tableColumn is malformed." withID:QLP_UnknownError];
                        isTransactionOK = NO;
                        break;
                    }
                    [tableAndColumns addObject:column];
                }
                
                // Attempt to insert the values
                if (![QL_quickLiteDatabase insertValues:values forColumns:tableAndColumns inTable:table]) {
                    isTransactionOK = NO;
                    break;
                }
            }
            
            if (!isTransactionOK)
                break;
        }
    }
    
    // Delete the rows marked for deletion
    if (isTransactionOK) {
        NSEnumerator *enumerator = [QL_cacheDeletes keyEnumerator];
        NSString* key;
        
        while ((key = [enumerator nextObject])) {
            NSArray* keyInfo = [key componentsSeparatedByString:@":"];
            if ([keyInfo count] != 2) {
                [QL_quickLiteDatabase QLP_setLastError:"Cannot save the deletes for the cursor because the tableColumn is malformed." withID:QLP_UnknownError];
                isTransactionOK = NO;
                break;
            }
            
            NSString* tableAndColumn = [keyInfo objectAtIndex:0];
            NSNumber* rowUID = [NSNumber numberWithDouble:[[keyInfo objectAtIndex:1] doubleValue]];
            NSString* table = [QL_quickLiteDatabase QLP_prefixWithDotDelimiter:tableAndColumn];
            if (![QL_quickLiteDatabase deleteRowWithUID:rowUID inTable:table]) {
                isTransactionOK = NO;
                break;
            }
        }
    }
    
    if (isTransactionOK) {
        if (transactionSetHere)
            [QL_quickLiteDatabase commitTransaction];
        
        [QL_cacheEdits removeAllObjects];		
        [QL_cacheInserts removeAllObjects];		
        [QL_cacheDeletes removeAllObjects];
        
        // Deregister with the database
        if (doDeregisterCursor)
            [QL_quickLiteDatabase QLP_deregisterModifiedCursor:self];
        
        // Refresh its contents
        [self refresh];
        
    } else {
        if (transactionSetHere)
            [QL_quickLiteDatabase rollbackTransaction];
    }
    
    return isTransactionOK;
}

- (void)QLP_revertAndDeregisterCursor:(BOOL)doDeregisterCursor
{	
    // Eliminate the re-read rows that were marked for deletion previously and add them
    // to QL_cache
    NSEnumerator *enumerator = [QL_cacheDeletes keyEnumerator];
    NSString* key;
    
    while ((key = [enumerator nextObject])) {
        NSMutableDictionary* keyInfo = [QL_cacheDeletes objectForKey:key];
        [QL_cache addObject:keyInfo];
    }
    
    [QL_cacheEdits removeAllObjects];	
    [QL_cacheInserts removeAllObjects];
    [QL_cacheDeletes removeAllObjects];
    
    // Deregister with the database
    if (doDeregisterCursor)
        [QL_quickLiteDatabase QLP_deregisterModifiedCursor:self];
}

- (id)QLP_objectFromSQLiteData:(const char*)data withColumn:(NSString*)tableAndColumn
{
    id returnedValue = nil;
    
    if (data) {
        // Find out the column datatype
        QLDatatype columnDatatype = [QL_quickLiteDatabase QLP_datatypeForColumn:tableAndColumn];
        
        if (columnDatatype == QL_Container ) {
            // Convert the BLOB to a string we can process...
            NSString* preparedEncodedHexData = [NSString stringWithUTF8String:data];
            if (!preparedEncodedHexData)
                return nil;
            
            // Try to locate the SQLite BLOB tag, because we'll have to extract the real
            // BLOB data from 'preparedEncodedHexData'...
            NSString* sqliteXTag = @"X'";
            NSRange r = [preparedEncodedHexData rangeOfString:sqliteXTag];
            if (r.location == NSNotFound)
                return nil;
            
            // Prepare the range where the real BLOB resides...
            r.location = [sqliteXTag length];
            r.length = [preparedEncodedHexData length] - r.location - 1;
            // Extract the BLOB and convert it to an NSData object...
            returnedValue = [QL_quickLiteDatabase decodeDataFromBase64:[preparedEncodedHexData substringWithRange:r]];
        } else {
            NSString *dateStr = nil;
            NSRange range;
            
            switch (columnDatatype) {
                case QL_RowID:
                    returnedValue = [NSNumber numberWithDouble:[[NSString stringWithUTF8String:data] doubleValue]];
                    break;
                case QL_String:
                    returnedValue = [NSString stringWithUTF8String:data];
                    break;
                case QL_Number:
                    returnedValue = [NSNumber numberWithDouble:[[NSString stringWithUTF8String:data] doubleValue]];
                    break;
                case QL_Boolean:
                    returnedValue = [NSNumber numberWithInt:[[NSString stringWithUTF8String:data]intValue]];
                    break;
                case QL_DateTime:
                    dateStr = [NSString stringWithUTF8String: data];
                    range = [dateStr rangeOfString:@":" options:NSBackwardsSearch];
                    if (range.location != NSNotFound) {
                        returnedValue = [NSCalendarDate dateWithString:[dateStr substringToIndex:range.location]];
                        [returnedValue addTimeInterval:[[dateStr substringFromIndex:range.location + 1]doubleValue]];
                    }
                    break;
                default:
                    // Since we don't know the datatype, just return the data as string
                    returnedValue = [NSString stringWithUTF8String:data];
            }
        }
    }
    
    return returnedValue;
}

- (BOOL)QLP_validateValue:(id)value forColumn:(NSString*)tableAndColumn startAtIndex:(unsigned long)index
{
    if (index > [self rowCount]) {
        [QL_quickLiteDatabase QLP_setLastError:"the index supplied is out of bounds" withID:QLP_UnknownError];
        return NO;
    }
    
    return [self QLP_validateValue:(id)value forColumn:(NSString*)tableAndColumn];
}

- (BOOL)QLP_validateValue:(id)value forColumn:(NSString*)tableAndColumn
{
    NSString* table = [QL_quickLiteDatabase QLP_prefixWithDotDelimiter:tableAndColumn];
    NSString* column = [QL_quickLiteDatabase QLP_suffixWithDotDelimiter:tableAndColumn];
    
    if ([table isEqualToString:tableAndColumn]) {
        [QL_quickLiteDatabase QLP_setLastError:[[NSString stringWithFormat:@"the table name cannot be extracted from: '%@'", tableAndColumn]UTF8String] withID:QLP_UnknownError];
        return NO;
    }
    
    if ([column isEqualToString:tableAndColumn]) {
        [QL_quickLiteDatabase QLP_setLastError:[[NSString stringWithFormat:@"the column name cannot be extracted from: '%@'", tableAndColumn]UTF8String] withID:QLP_UnknownError];;
        return NO;
    }
    
    if (!value) {
        [QL_quickLiteDatabase QLP_setLastError:"the value supplied is nil" withID:QLP_UnknownError];
        return NO;
    }
    
    QLDatatype columnDatatype = [QL_quickLiteDatabase QLP_datatypeForTable:table column:column];
    
    BOOL canWeSearch = YES;
    
    switch (columnDatatype) {
        case QL_String:
            if (![value isKindOfClass:[NSString class]])
                canWeSearch = NO;
            break;
        case QL_Number:
            if (![value isKindOfClass:[NSNumber class]])
                canWeSearch = NO;
            break;
        case QL_Boolean:
            if (![value isKindOfClass:[NSNumber class]])
                canWeSearch = NO;
            break;
        case QL_DateTime:
            if (![value isKindOfClass:[NSCalendarDate class]])
                canWeSearch = NO;
            break;
        case QL_Container:
            if (![value isKindOfClass:[NSData class]])
                canWeSearch = NO;
            break;
        case QL_RowID:
            if (![value isKindOfClass:[NSNumber class]])
                canWeSearch = NO;
            break;
        default:
            canWeSearch = NO;
    }
    
    if (!canWeSearch)
        [QL_quickLiteDatabase QLP_setLastError:[[NSString stringWithFormat:@"the value type supplied for column '%@' does not match its datatype", column]UTF8String] withID:QLP_UnknownError];
    
    return canWeSearch;
}

- (void)QLP_adjustDictionaryValuesWithQuickEditData:(NSMutableDictionary*)values forRow:(unsigned long)rowIndex
{
    NSString* UUID = [[QL_cache objectAtIndex:rowIndex]objectForKey:QLP_UUID];
    if (!UUID)
        return;
    
    // Update the dictionary with the modified values
    NSDictionary* tables = [QL_cacheEdits objectForKey:UUID];
    if (tables) {
        NSEnumerator *tableEnum = [tables keyEnumerator];
        NSString* table;
        
        while ((table = [tableEnum nextObject])) {
            NSDictionary* tableInfo = [tables objectForKey:table];
            if (tableInfo) {
                // Now traverse the dictionary and update the values with keys having the
                // proper prefix.
                NSString* tablePrefix = [NSString stringWithFormat:@"%@.", table];
                NSEnumerator *columnEnum = [tableInfo keyEnumerator];
                NSString* column;
                
                while ((column = [columnEnum nextObject])) {
                    if ([column hasPrefix:tablePrefix])
                        [values setObject:[tableInfo objectForKey:column] forKey:column];
                }
            }
        }
    }
}

- (NSMutableArray*)QLP_removeObject:(id)value fromArray:(NSMutableArray*)array
{
    long i = [array count] - 1;
    
    while (i >= 0) {
        if ([[array objectAtIndex:i]isEqualTo:value])
            [array removeObjectAtIndex:i];
        i--;
    }
    
    return array;
}

- (void)QLP_releaseOurQuickLiteDatabase:(NSNotification*)info
{
    QuickLiteDatabase* db = [info object];
    
    if (db == QL_quickLiteDatabase) {
        QL_quickLiteDatabase = nil;
        
        // We no longer listen at this point...
        [[NSNotificationCenter defaultCenter] removeObserver:self name:QLP_QuickLiteDatabaseDidCloseNotification object:nil];
    }
}

- (unsigned long)QLP_matchingRowWithValue:(id)value forColumn:(NSString*)tableAndColumn startAtIndex:(unsigned long)index comparisonMethod:(unsigned)method
{
    QLDatatype columnDatatype = [QL_quickLiteDatabase QLP_datatypeForColumn:tableAndColumn];
    unsigned long i, count = [self rowCount], location = NSNotFound;
    
    for (i = index; i < count; i++) {
        id rowValue = [self QLP_valueForColumn:tableAndColumn andRow:i treatValuesAsString:NO];
        
        switch (columnDatatype) {
            case QL_String:
                if ([value compare:rowValue options:method] == NSOrderedSame) {
                    location = i;
                    i = count;
                }
                break;
            case QL_Number:
            case QL_Boolean:
            case QL_RowID:
                if ([value isEqualToNumber:rowValue]) {
                    location = i;
                    i = count;
                }
                break;
            case QL_DateTime:
                if ([value isEqualToDate:rowValue]) {
                    location = i;
                    i = count;
                }
                break;
            case QL_Container:
                if ([value isEqualToData:rowValue]) {
                    location = i;
                    i = count;
                }
                break;
            default:
                break;
        }
    }
    
    return location;
}

- (NSArray*)QLP_matchingRowsWithValue:(id)value forColumn:(NSString*)tableAndColumn comparisonMethod:(unsigned)method
{
    if (![self QLP_validateValue:value forColumn:tableAndColumn]) {
        [QL_quickLiteDatabase QLP_setLastError:"[QuickLiteCursor matchingRowsWithValues: forColumn: setOperation: comparisonMethod:] failed: value and datatype mismatch." withID: QLP_UnknownError];
        return nil;
    }

    NSMutableArray* tempValuesArray = [NSMutableArray array];
    QLDatatype columnDatatype = [QL_quickLiteDatabase QLP_datatypeForColumn:tableAndColumn];
    unsigned long i, count = [self rowCount];
    
    for (i = 0; i < count; i++) {
        id rowValue = [self QLP_valueForColumn:tableAndColumn andRow:i treatValuesAsString:NO];
        
        switch (columnDatatype) {
            case QL_String:
                if ([value compare:rowValue options:method] == NSOrderedSame)
                    [tempValuesArray addObject:[NSNumber numberWithLong:i]];
                break;
            case QL_Number:
            case QL_Boolean:
            case QL_RowID:
                if ([value isEqualToNumber:rowValue])
                    [tempValuesArray addObject:[NSNumber numberWithLong:i]];
                break;
            case QL_DateTime:
                if ([value isEqualToDate:rowValue])
                    [tempValuesArray addObject:[NSNumber numberWithLong:i]];
                break;
            case QL_Container:
                if ([value isEqualToData:rowValue])
                    [tempValuesArray addObject:[NSNumber numberWithLong:i]];
                break;
            default:
                break;
        }
    }
    
    return [NSArray arrayWithArray:tempValuesArray];
}

- (NSDictionary*)QLP_verifyCursorsForSetOperation:(QuickLiteCursor*)cursor
{
    // Make sure both cursors are the same
    NSArray *a = [[self tables] sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)];
    NSArray *b = [[cursor tables] sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)];
    
    if ([a isEqualToArray:b] == NO) {
        [QL_quickLiteDatabase QLP_setLastError:"the two cursors have a different set of tables" withID:QLP_UnknownError];
        return nil;
    }
    
    // Make sure only one table exists
    if ([a count] != 1) {
        [QL_quickLiteDatabase QLP_setLastError:"set operations can only be performed on cursors with one table reference" withID:QLP_UnknownError];
        return nil;
    }
    
    // Make sure the rowUID is referenced...
    NSString *table = [a objectAtIndex:0];
    NSString *tableAndROWUID = [NSString stringWithFormat:@"%@.%@", table, QLRecordUID];
    NSArray *columnsA = [self columns];
    if ([columnsA containsObject:tableAndROWUID] == NO) {
        [QL_quickLiteDatabase QLP_setLastError:"set operations need the ROWUID column in order to work" withID:QLP_UnknownError];
        return nil;
    }
    NSArray *columnsB = [cursor columns];
    if ([columnsB containsObject:tableAndROWUID] == NO) {
        [QL_quickLiteDatabase QLP_setLastError:"set operations need the ROWUID column in order to work" withID:QLP_UnknownError];
        return nil;
    }

    // Obtain the columns referenced in the two cursors
    NSMutableSet *referencedColumnsSet = [[NSMutableSet alloc]init];
    [referencedColumnsSet addObjectsFromArray:columnsA];
    [referencedColumnsSet addObjectsFromArray:columnsB];
    NSArray *referencedColumns = [referencedColumnsSet allObjects];
    [referencedColumnsSet release];

    // Obtain their datatypes
    NSMutableDictionary *datatypes = [NSMutableDictionary dictionary];
    NSArray *allColumns = [QL_quickLiteDatabase columnsForTable:table];
    NSArray *allDatatypes = [QL_quickLiteDatabase datatypesForTable:table];
    int i, count = [allDatatypes count];
    
    for (i = 0; i < count; i++) {
        NSString *column = [allColumns objectAtIndex:i];
        NSString *datatype = [allDatatypes objectAtIndex:i];
        NSString *tableAndColumn = [NSString stringWithFormat:@"%@.%@", table, column];
        if ([referencedColumns containsObject:tableAndColumn])
            [datatypes setObject:datatype forKey:column];
    }
    
    return datatypes;
}

@end