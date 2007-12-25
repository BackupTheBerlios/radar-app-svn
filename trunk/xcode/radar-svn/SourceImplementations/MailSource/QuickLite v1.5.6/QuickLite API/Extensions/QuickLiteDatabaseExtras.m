/*
 *  QuickLiteDatabaseExtras.m
 *  A lightweight Cocoa wrapper for SQLite
 *  
 *  Written by Tito Ciuro (20-May-2004)

	Copyright (c) 2004, Tito Ciuro
	All rights reserved.

	Redistribution and use in source and binary forms, with or without modification, are permitted
	provided that the following conditions are met:
	
	¥ 	Redistributions of source code must retain the above copyright notice, this list of conditions
		and the following disclaimer.
	¥	Redistributions in binary form must reproduce the above copyright notice, this list of conditions
		and the following disclaimer in the documentation and/or other materials provided with the distribution.
	¥	Neither the name of Tito Ciuro nor the names of its contributors may be used to endorse or promote
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
#import "QuickLiteDatabaseExtras.h"
#import "QuickLiteRow.h"

static NSArray* sharedROWIDKeywords = nil;
static NSSet* sharedQuickLiteDatatypes = nil;

int QLP_commitCallback(void* qldb);

@implementation QuickLiteDatabase (QuickLiteDatabaseExtras)

+ (NSArray*)sharedROWIDKeywords
{
    if (sharedROWIDKeywords == nil)
        sharedROWIDKeywords = [[NSArray alloc] initWithObjects:@"ROWID", @"OID", @"_ROWID_", nil];
    
    return sharedROWIDKeywords;
}

+ (NSSet*)sharedQuickLiteDatatypes
{
    if (sharedQuickLiteDatatypes == nil)
        sharedQuickLiteDatatypes = [[NSSet alloc] initWithObjects:QLRecordUIDDatatype, QLString, QLNumber, QLBoolean, QLDateTime, QLContainer, nil];
    
    return sharedQuickLiteDatatypes;
}

#pragma mark Transaction Methods

- (BOOL)beginTransaction
{
    return [self beginDeferredTransaction];
}

- (BOOL)beginDeferredTransaction
{
    return [self QLP_beginTransactionMode:@"BEGIN DEFERRED TRANSACTION;"];
}

- (BOOL)beginImmediateTransaction
{
    return [self QLP_beginTransactionMode:@"BEGIN IMMEDIATE TRANSACTION;"];
}

- (BOOL)beginExclusiveTransaction
{
    return [self QLP_beginTransactionMode:@"BEGIN EXCLUSIVE TRANSACTION;"];
}

- (BOOL)commitTransaction
{
    // Log info if required...
    [self QLP_logIfInDebugMode:_cmd forClass:[self class]];
    
    if ([self isTransactionActive])
        return [self QLP_performExecuteQuery:@"COMMIT TRANSACTION;"];
    
    return NO;
}

- (BOOL)rollbackTransaction
{
    // Log info if required...
    [self QLP_logIfInDebugMode:_cmd forClass:[self class]];
    
    if ([self isTransactionActive])
        return [self QLP_performExecuteQuery:@"ROLLBACK TRANSACTION;"];
    
    return NO;
}

#pragma mark Table Methods

- (BOOL)createTable:(NSString*)table withColumns:(NSArray*)columns andDatatypes:(NSArray*)datatypes
{
    // Log info if required...
    [self QLP_logIfInDebugMode:_cmd forClass:[self class]];
    
    return [self QLP_createTable:table withColumns:columns andDatatypes:datatypes isTemporary:NO];
}

- (BOOL)createTemporaryTable:(NSString*)table withColumns:(NSArray*)tableColumns andDatatypes:(NSArray*)tableDatatypes
{
    // Log info if required...
    [self QLP_logIfInDebugMode:_cmd forClass:[self class]];
    
    return [self QLP_createTable:table withColumns:tableColumns andDatatypes:tableDatatypes isTemporary:YES];
}

- (BOOL)copyTable:(NSString*)src toTable:(NSString*)dst
{
    // Log info if required...
    [self QLP_logIfInDebugMode:_cmd forClass:[self class]];
    
    NSArray* tables = [self tables];
    if ((![tables containsObject:src]) || (![tables containsObject:dst]))
        return NO;
    
    NSArray* srcDatatypes = [self datatypesForTable:src];
    NSArray* dstDatatypes = [self datatypesForTable:dst];
    
    if (![srcDatatypes isEqualToArray:dstDatatypes])
        return NO;
    
    BOOL transactionSetHere = NO;
    if ([self isTransactionActive] == NO)
        transactionSetHere = [self beginTransaction];
    
    BOOL deleteWasOK = NO, insertWasOK = NO;
    deleteWasOK = [self QLP_performExecuteQuery:[NSString stringWithFormat:@"DELETE FROM %@;", dst]];		
    if (deleteWasOK) {
        insertWasOK = [self QLP_performExecuteQuery:[NSString stringWithFormat: @"INSERT INTO %@ SELECT * FROM %@", dst, src]];
    }
    
    NSString* error = [self lastError];
    int lastErrorID = [self lastErrorID];

    if (transactionSetHere) {
        if (deleteWasOK && insertWasOK)
            [self commitTransaction];
        else
            [self rollbackTransaction];
    }
    
    [self QLP_setLastError:[error UTF8String] withID: lastErrorID];
    
    return (deleteWasOK && insertWasOK);
}

- (BOOL)dropTable:(NSString*)table
{
    // Log info if required...
    [self QLP_logIfInDebugMode:_cmd forClass:[self class]];
    
    if (table == nil) {
        [self QLP_setLastError:"QuickLite:dropTable has failed because the supplied parameter is nil." withID:QLP_UnknownError];
        return NO;
    }
    
    BOOL transactionSetHere = NO;
    if (![self isTransactionActive])
        transactionSetHere = [self beginTransaction];
    
    NSString* sqlQuery = [[NSString alloc]initWithFormat:@"DROP TABLE %@;", table];
    BOOL everythingIsFine = [self QLP_performExecuteQuery:sqlQuery];
    [sqlQuery release];
    
    if (everythingIsFine) {
        sqlQuery = [[NSString alloc]initWithFormat:@"DELETE FROM %@ WHERE %@ = '%@';", QLP_SchemaTable, QLP_TableIdentifier, table];
        everythingIsFine = [self QLP_performExecuteQuery:sqlQuery];
        [sqlQuery release];
    }
    
    if (transactionSetHere) {
        if (everythingIsFine) {
            [self commitTransaction];
        } else {
            [self rollbackTransaction];
        }
    }
    
    if (everythingIsFine)
        [self QLP_rebuildDatatypeCache];
    
    return everythingIsFine;
}

- (BOOL)addColumn:(NSString*)column withDataType:(NSString*)datatype toTable:(NSString*)table
{
    // Log info if required...
    [self QLP_logIfInDebugMode:_cmd forClass:[self class]];
    
    // Obtain all current columns and datatypes for table
    NSArray* tableInfoDatatypes = [self datatypesForTable:table];

    if (tableInfoDatatypes == nil) {
        [self QLP_setLastError:"QuickLite:addColumn has failed because tableInfoDatatypes is nil." withID:QLP_UnknownError];
        return NO;
    }
    
    NSSet* allowedDatatypes = [QuickLiteDatabase sharedQuickLiteDatatypes];
    if (![allowedDatatypes containsObject:datatype]) {
        [self QLP_setLastError:[[NSString stringWithFormat:@"QuickLite:addColumn has failed because %@ is not standard datatype.", datatype] UTF8String] withID:QLP_UnknownError];
        return NO;
    }
    
    NSArray* tableInfoColumns = [self columnsForTable:table];
    
    // Add the new column and data type to the list
    NSMutableArray* tableColumns = [[NSMutableArray alloc] initWithArray:tableInfoColumns];
    NSMutableArray* tableDatatypes = [[NSMutableArray alloc] initWithArray:tableInfoDatatypes];
    [tableColumns addObject:column];
    [tableDatatypes addObject:datatype];
    
    BOOL everythingIsFine = YES;
    
    BOOL transactionSetHere = NO;
    if (![self isTransactionActive])
        transactionSetHere = [self beginTransaction];
    
    // Create a backup table with the columns and datatypes
    BOOL isTableTemporary = [[self temporaryTables] containsObject:table];
    if (![self QLP_createTable:[NSString stringWithFormat:@"%@_backup", table] withColumns:tableColumns andDatatypes:tableDatatypes isTemporary:isTableTemporary])
        everythingIsFine = NO;
    
    // Insert all existing data
    NSMutableString* query = [NSMutableString stringWithString:[NSString stringWithFormat:@"INSERT INTO %@_backup(", table]];
    
    [self QLP_sqlString:query appendingTags:tableInfoColumns];
    [query appendString:@") SELECT "];
    [self QLP_sqlString:query appendingTags:tableInfoColumns];
    
    everythingIsFine = [self QLP_performExecuteQuery:[NSString stringWithFormat:@"%@ FROM %@;", query, table]];
    
    // Delete the old table
    if (![self dropTable:table])
        everythingIsFine = NO;
    
    // Create the new table with the columns and datatypes
    isTableTemporary = [[self temporaryTables] containsObject:table];
    if (![self QLP_createTable:table withColumns:tableColumns andDatatypes:tableDatatypes isTemporary:isTableTemporary])
        everythingIsFine = NO;
    
    // Copy the data from the backup table
    query = [NSMutableString stringWithString:[NSString stringWithFormat:@"INSERT INTO %@(", table]];
    
    [self QLP_sqlString:query appendingTags:tableColumns];
    [query appendString:@") SELECT "];
    [self QLP_sqlString:query appendingTags:tableColumns];
    
    everythingIsFine = [self QLP_performExecuteQuery:[NSString stringWithFormat:@"%@ FROM %@_backup;", query, table]];
    
    // Delete the backup table
    if (![self dropTable:[NSString stringWithFormat:@"%@_backup", table]])
        everythingIsFine = NO;
    
    // Cleanup
    [tableColumns release];
    [tableDatatypes release];
    
    if (transactionSetHere) {
        if (everythingIsFine) {
            [self commitTransaction];
        } else {
            [self rollbackTransaction];
        }
    }
    
    if (everythingIsFine)
        [self QLP_rebuildDatatypeCache];
    
    return everythingIsFine;
}

- (BOOL)removeColumn:(NSString*)column fromTable:(NSString*)table
{
    // Log info if required...
    [self QLP_logIfInDebugMode:_cmd forClass:[self class]];
    
    return [self QLP_removeColumn:column fromTable:table];
}

- (NSArray*)tableInfo:(NSString*)table
{
    QuickLiteCursor* cursor = [self performQuery: [NSString stringWithFormat: @"PRAGMA table_info(%@);", table]];
    NSMutableArray* info = [NSMutableArray array];
    unsigned long i, count = [cursor rowCount];
    
    for (i = 0; i < count; i++)
        [info addObject: [cursor valuesForRow: i]];
    
    return info;
}

- (BOOL)insertValues:(NSArray*)values forColumns:(NSArray*)columns inTable:(NSString*)table
{
    // Log info if required...
    [self QLP_logIfInDebugMode:_cmd forClass:[self class]];
    
    NSMutableArray* escapedValues = [[NSMutableArray alloc] init];
    int i, count = [columns count];
    BOOL isInsertionOK = YES;
    
    BOOL transactionSetHere = NO;
    if (![self isTransactionActive])
        transactionSetHere = [self beginTransaction];
    
    for (i = 0; i < count; i++) {
        NSString* column = [columns objectAtIndex:i];
        id value = [values objectAtIndex:i];
        NSString* stringValue = nil;

        QLDatatype columnDatatype = [self QLP_datatypeForTable:table column:column];
        
        if ([value isKindOfClass:[NSNull class]] == NO) {
            switch (columnDatatype) {
                case QL_String:
                    if (![value isKindOfClass:[NSString class]])
                        isInsertionOK = NO;
                    else
                        stringValue = value;
                    break;
                case QL_Number:
                    if (![value isKindOfClass:[NSNumber class]])
                        isInsertionOK = NO;
                    else
                        stringValue = [value stringValue];
                    break;
                case QL_Boolean:
                    if (![value isKindOfClass:[NSNumber class]]) {
                        isInsertionOK = NO;
                    } else {
                        if ([value boolValue])
                            stringValue = @"1";
                        else
                            stringValue = @"0";
                    }
                    break;
                case QL_DateTime:
                    if (![value isKindOfClass:[NSCalendarDate class]]) {
                        isInsertionOK = NO;
                    } else {
                        NSString *dateStr = [value descriptionWithCalendarFormat:nil timeZone:nil locale:nil];
                        NSCalendarDate *newDate = [NSCalendarDate dateWithString: dateStr];
                        NSTimeInterval interval = fabs([value timeIntervalSinceDate:newDate]);
                        stringValue = [NSString stringWithFormat:@"%@:%g", dateStr, interval];
                    }
                    break;
                case QL_Container:
                    if (![value isKindOfClass:[NSData class]]) {
                        isInsertionOK = NO;
                    } else {
                        // Encode the BLOB in a way SQLite v3 understands: enclosed within X'<my real BLOB data>'...
                        stringValue = [QuickLiteDatabase prepareStringForQuery:[NSString stringWithFormat:@"X'%@'", [self encodeDataToBase64:value]]];
                    }
                    break;
                case QL_RowID:
                default:
                    if ((![value isKindOfClass:[NSNull class]]) && (![value isKindOfClass:[NSNumber class]]))
                        isInsertionOK = NO;
                    else
                        stringValue = @"NULL";
                    break;
            }
        }

        if (isInsertionOK) {
            if ([self QLP_isColumnROWIDAlias:column forTable:table] == NO) {
                NSString* escapedValue = [[NSString alloc]initWithFormat:@"'%@'", stringValue];
                [escapedValues addObject:escapedValue];
                // Cleanup
                [escapedValue release];
            } else {
                if (value == [NSNull null])
                    [escapedValues addObject:@"NULL"];
                else
                    [escapedValues addObject:[value stringValue]];
            }
        } else {
            // Set the error and get out of the loop...
            [self QLP_setLastError:[[NSString stringWithFormat:@"the value type supplied for column '%@' does not match its datatype", column]UTF8String] withID:QLP_UnknownError];
            break;
        }
    }
    
    if (isInsertionOK) {
        NSMutableString* sqlQuery = [[NSMutableString alloc]initWithString:@"INSERT INTO "];
        [sqlQuery appendString:table];
        [sqlQuery appendString:@"("];
        [self QLP_sqlString:sqlQuery appendingTags:columns];
        [sqlQuery appendString:@") VALUES("];
        [self QLP_sqlString:sqlQuery appendingTags:escapedValues];
        [sqlQuery appendString:@");"];
        isInsertionOK = [self QLP_performExecuteQuery:sqlQuery];
        
        // Cleanup
        [sqlQuery release];
    }
    
    if (transactionSetHere) {
        if (isInsertionOK)
            [self commitTransaction];
        else
            [self rollbackTransaction];
    }
    
    // Cleanup
    [escapedValues release];
    
    return isInsertionOK;
}

- (BOOL)updateValues:(NSArray*)values forColumns:(NSArray*)columns withRowUID:(NSNumber*)rowUID inTable:(NSString*)table
{
    // Log info if required...
    [self QLP_logIfInDebugMode:_cmd forClass:[self class]];
    
    if ((!values) | (!columns) | (!rowUID) | (!table)) {
        [self QLP_setLastError:"Some/all of the values supplied are nil." withID:QLP_UnknownError];
        return NO;
    }
    
    NSMutableArray* escapedValues = [[NSMutableArray alloc] init];
    int i, count = [columns count];
    BOOL isUpdateOK = YES;
    
    for (i = 0; i < count; i++) {
        id value = [values objectAtIndex:i];
        NSString* column = [self QLP_suffixWithDotDelimiter:[columns objectAtIndex:i]];
        
        QLDatatype columnDatatype = [self QLP_datatypeForTable:table column:column];
        
        id objectValue = nil;
        
        if (value == [NSNull null]) {
            objectValue = value;
        } else {
            switch (columnDatatype) {
                case QL_String:
                    if (![value isKindOfClass:[NSString class]])
                        isUpdateOK = NO;
                    else
                        objectValue = value;
                    break;
                case QL_RowID:
                    // We don't care about its content type, since we'll ignore it...
                    break;
                case QL_Number:
                    if (![value isKindOfClass:[NSNumber class]])
                        isUpdateOK = NO;
                    else
                        objectValue = [value stringValue];
                    break;
                case QL_Boolean:
                    if (![value isKindOfClass:[NSNumber class]]) {
                        isUpdateOK = NO;
                    } else {
                        if ([value boolValue])
                            objectValue = @"1";
                        else
                            objectValue = @"0";
                    }
                    break;
                case QL_DateTime:
                    if (![value isKindOfClass:[NSCalendarDate class]]) {
                        isUpdateOK = NO;
                    } else {
                        NSString *dateStr = [value descriptionWithCalendarFormat:nil timeZone:nil locale:nil];
                        NSCalendarDate *newDate = [NSCalendarDate dateWithString: dateStr];
                        NSTimeInterval interval = fabs([value timeIntervalSinceDate:newDate]);
                        objectValue = [NSString stringWithFormat:@"%@:%g", dateStr, interval];
                    }
                    break;
                case QL_Container:
                    if (![value isKindOfClass:[NSData class]])
                        isUpdateOK = NO;
                    else
                        // Encode the BLOB in a way SQLite v3 understands: enclosed within X'<my real BLOB data>'...
                        objectValue = [QuickLiteDatabase prepareStringForQuery:[NSString stringWithFormat:@"X'%@'", [self encodeDataToBase64:value]]];
                    break;
                default:
                    if ((![value isKindOfClass:[NSNull class]]) && (![value isKindOfClass:[NSNumber class]]))
                        isUpdateOK = NO;
                    else
                        objectValue = [NSNull null];
                    break;
            }
        }
        
        if (isUpdateOK) {
            NSString* escapedValue = nil;
            
            if (objectValue == [NSNull null])
                escapedValue = @"NULL";
            else
                escapedValue = [[NSString alloc]initWithFormat:@"'%@'", objectValue];
            
            [escapedValues addObject:escapedValue];
            // Cleanup
            [escapedValue release];
        } else {
            [self QLP_setLastError:[[NSString stringWithFormat:@"the value type supplied for column '%@' does not match its datatype", column]UTF8String] withID:QLP_UnknownError];
        }
    }
    
    if (isUpdateOK) {
        NSMutableArray* assignments = [[NSMutableArray alloc] init];
        for (i = 0; i < count; i++) {
            NSString* column = [self QLP_suffixWithDotDelimiter:[columns objectAtIndex:i]];
            if (![self QLP_isColumnROWIDAlias:column forTable:table])
                [assignments addObject:[NSString stringWithFormat:@"%@ = %@", column, [escapedValues objectAtIndex:i]]];
        }

        NSMutableString* sqlQuery = [[NSMutableString alloc]initWithString:@"UPDATE "];
        [sqlQuery appendString:table];
        [sqlQuery appendString:@" SET "];
        [sqlQuery appendString:[assignments componentsJoinedByString:@", "]];
        [sqlQuery appendString:[NSString stringWithFormat:@" WHERE %@.%@ = '%@';", table, QLRecordUID, rowUID]];
        
        isUpdateOK = [self QLP_performExecuteQuery:sqlQuery];
        
        // Cleanup
        [sqlQuery release];
        [assignments release];
    }
    
    // Cleanup
    [escapedValues release];
    
    return isUpdateOK;
}

- (BOOL)deleteRowWithUID:(NSNumber*)rowUID inTable:(NSString*)table
{
    // Log info if required...
    [self QLP_logIfInDebugMode:_cmd forClass:[self class]];
    
    if (!rowUID)
        return NO;
    
    if (!table)
        return NO;
    
    BOOL transactionSetHere = NO;
    if (![self isTransactionActive])
        transactionSetHere = [self beginTransaction];
    
    NSString* rowUIDColumn = [[NSString alloc]initWithFormat:@"%@.%@", table, QLRecordUID];
    NSString* sqlQuery = [[NSString alloc]initWithFormat:@"DELETE FROM %@ WHERE %@ = '%@';", table, rowUIDColumn, [rowUID stringValue]];
    BOOL deleteWasOK = [self QLP_performExecuteQuery:sqlQuery];
    
    if (transactionSetHere) {
        if (deleteWasOK)
            [self commitTransaction];
        else
            [self rollbackTransaction];
    }
    
    // Cleanup
    [rowUIDColumn release];
    [sqlQuery release];
    
    return deleteWasOK;
}

- (BOOL)deleteRowsWithUIDObjects:(NSArray*)rowUIDs inTable:(NSString*)table
{
    // Log info if required...
    [self QLP_logIfInDebugMode:_cmd forClass:[self class]];
    
    BOOL transactionSetHere = NO;
    if (![self isTransactionActive])
        transactionSetHere = [self beginTransaction];
    
    unsigned long i, count = [rowUIDs count];
    BOOL allDeletesOK = YES;
    
    for (i = 0; i < count; i++) {
        if (![self deleteRowWithUID:[rowUIDs objectAtIndex: i] inTable:table]) {
            allDeletesOK = NO;
            break;
        }
    }
    
    if (transactionSetHere) {
        if (allDeletesOK)
            [self commitTransaction];
        else
            [self rollbackTransaction];
    }
    
    return allDeletesOK;
}

- (BOOL)deleteRowsWithValue:(id)value forColumn:(NSString*)column inTable:(NSString*)table
{
    // Log info if required...
    [self QLP_logIfInDebugMode:_cmd forClass:[self class]];
    
    if ((!value) | (!column) | (!table))
        return NO;
    
    NSString* stringValue = nil;
    QLDatatype columnDatatype = QL_Unknown;
    BOOL isDeleteOK = YES;
    
    if ([value isKindOfClass:[NSNull class]] == NO) {
        columnDatatype = [self QLP_datatypeForTable:table column:column];
        
        switch (columnDatatype) {
            case QL_String:
                if (![value isKindOfClass:[NSString class]])
                    isDeleteOK = NO;
                else
                    stringValue = value;
                break;
            case QL_Number:
                if (![value isKindOfClass:[NSNumber class]])
                    isDeleteOK = NO;
                else
                    stringValue = [value stringValue];
                break;
            case QL_Boolean:
                if (![value isKindOfClass:[NSNumber class]]) {
                    isDeleteOK = NO;
                } else {
                    if ([value boolValue])
                        stringValue = @"1";
                    else
                        stringValue = @"0";
                }
                break;
            case QL_DateTime:
                if (![value isKindOfClass:[NSCalendarDate class]]) {
                    isDeleteOK = NO;
                } else {
                    NSString *dateStr = [value descriptionWithCalendarFormat:nil timeZone:nil locale:nil];
                    NSCalendarDate *newDate = [NSCalendarDate dateWithString: dateStr];
                    NSTimeInterval interval = fabs([value timeIntervalSinceDate:newDate]);
                    stringValue = [NSString stringWithFormat:@"%@:%g", dateStr, interval];
                }
                break;
            case QL_Container:
                if (![value isKindOfClass:[NSData class]])
                    isDeleteOK = NO;
                else
                    // Encode the BLOB in a way SQLite v3 understands: enclosed within X'<my real BLOB data>'...
                    stringValue = [QuickLiteDatabase prepareStringForQuery:[NSString stringWithFormat:@"X'%@'", [self encodeDataToBase64:value]]];
                break;
            case QL_RowID:
                if (![value isKindOfClass:[NSNumber class]])
                    isDeleteOK = NO;
                else
                    stringValue = [value stringValue];
                break;
            default:
                isDeleteOK = NO;
        }
    }
    
    if (isDeleteOK) {
        NSMutableString* sqlQuery = nil;
        
        switch (columnDatatype) {
            case QL_RowID:
                sqlQuery = [[NSMutableString alloc]initWithFormat:@"DELETE FROM %@ WHERE %@.%@ = %@;", table, table, column, value];
                break;
            case QL_String:
            case QL_Number:
            case QL_Boolean:
            case QL_DateTime:
            case QL_Container:
                sqlQuery = [[NSMutableString alloc]initWithFormat:@"DELETE FROM %@ WHERE %@.%@ = '%@';", table, table, column, stringValue];
                break;
            case QL_Unknown:
                sqlQuery = [[NSMutableString alloc]initWithFormat:@"DELETE FROM %@ WHERE %@.%@ IS NULL;", table, table, column];
                break;
            default:
                isDeleteOK = NO;
        }
        
        if (isDeleteOK)
            isDeleteOK = [self QLP_performExecuteQuery:sqlQuery];
        
        // Cleanup
        [sqlQuery release];
    } else {
        [self QLP_setLastError:[[NSString stringWithFormat:@"the value type supplied for column '%@' does not match its datatype", column]UTF8String] withID:QLP_UnknownError];
    }
        
    return isDeleteOK;
}

- (BOOL)deleteAllRowsInTable:(NSString*)table
{
    // Log info if required...
    [self QLP_logIfInDebugMode:_cmd forClass:[self class]];
    
    BOOL transactionSetHere = NO;
    if (![self isTransactionActive])
        transactionSetHere = [self beginTransaction];
    
    BOOL deleteWasOK = [self QLP_performExecuteQuery: [NSString stringWithFormat:@"DELETE FROM %@;", table]];
    
    if (transactionSetHere) {
        if (deleteWasOK)
            [self commitTransaction];
        else
            [self rollbackTransaction];
    }
    
    return deleteWasOK;
}

- (unsigned long)rowCountInTable:(NSString*)table
{
    // Log info if required...
    [self QLP_logIfInDebugMode:_cmd forClass:[self class]];
    
    NSString* sqlQuery = [NSString stringWithFormat: @"SELECT COUNT(*) FROM %@", table];
    QuickLiteCursor* results = [self QLP_performInternalQuickLiteQuery: sqlQuery];
    
    if ([results rowCount] > 0) {
        QuickLiteRow* row = [results rowAtIndex: 0];
        return [[NSNumber numberWithDouble: [[row stringForColumn: @"COUNT(*)"] doubleValue]] unsignedLongValue];
    }
    
    return 0;
}

- (BOOL)createIndexForColumn:(NSString*)column inTable:(NSString*)table isUnique:(BOOL)flag
{
    // Log info if required...
    [self QLP_logIfInDebugMode:_cmd forClass:[self class]];
    
    NSString* sqlQuery = nil;
    
    if (flag)
        sqlQuery = [[NSString alloc]initWithFormat:@"CREATE UNIQUE INDEX %@_%@_IDX ON %@ (%@);", table, column, table, column];
    else
        sqlQuery = [[NSString alloc]initWithFormat:@"CREATE INDEX %@_%@_IDX ON %@ (%@);", table, column, table, column];
    
    BOOL indexWasCreated = [self QLP_performExecuteQuery:sqlQuery];
    
    // Cleanup
    [sqlQuery release];
    
    return indexWasCreated;
}

- (void)dropIndex:(NSString*)indexName
{
    // Log info if required...
    [self QLP_logIfInDebugMode:_cmd forClass:[self class]];
    
    NSString* sqlQuery = [[NSString alloc]initWithFormat:@"DROP INDEX %@_IDX;", indexName];
    
    [self QLP_performExecuteQuery:sqlQuery];
    
    // Cleanup
    [sqlQuery release];
}

#pragma mark Private Methods

- (BOOL)QLP_beginTransactionMode:(NSString*)sqlQuery
{
    // Log info if required...
    [self QLP_logIfInDebugMode:_cmd forClass:[self class]];
    
    if (![self isTransactionActive]) {
        // Remember the SQL statement, if needed
        [self QLP_sendSQLStatement:sqlQuery];
        
        sqlite3_stmt *QL_sqliteVM;
        const char *query_tail = [sqlQuery UTF8String];
        
        int result = sqlite3_prepare([self QLP_sqliteDatabase], query_tail, -1, &QL_sqliteVM, &query_tail);
        const char* errMsg = NULL;
        
        // Set the busy timeout (by default is 1 second)
        [self setBusyTimeout:1 * 1000];
        
        if (result == QLSuccess) {
            BOOL continueTrying = YES;
            
            do {
                result = sqlite3_step(QL_sqliteVM);
                
                switch (result) {
                    case SQLITE_OK:
                    case SQLITE_DONE:
                        continueTrying = NO;
                        break;
                    case SQLITE_BUSY:
                        [self rollbackTransaction];
                        sqlite3_reset(QL_sqliteVM);
                        continueTrying = YES;
                        break;
                    default:
                        [self rollbackTransaction];
                        continueTrying = NO;
                        break;
                }
            } while (continueTrying);
            
            result = sqlite3_finalize(QL_sqliteVM);
            if (result != QLSuccess) {
                const char* errMsg = sqlite3_errmsg([self QLP_sqliteDatabase]);
                [self QLP_logIfInDebugMode:[NSString stringWithUTF8String:errMsg]];
                [self QLP_setLastError:errMsg  withID: result];
            } else {
                [self QLP_setLastError: NULL withID: QLSuccess];
            }
        } else {
            errMsg = sqlite3_errmsg([self QLP_sqliteDatabase]);
            [self QLP_logIfInDebugMode:[NSString stringWithUTF8String:errMsg]];
            [self QLP_setLastError:errMsg  withID: result];
        }
        
        return ([self lastErrorID] == QLSuccess);
    }
    
    return NO;
}

- (BOOL)QLP_createTable:(NSString*)table withColumns:(NSArray*)tableColumns andDatatypes:(NSArray*)tableDatatypes isTemporary:(BOOL)isTemporaryFlag
{
    if ((table == nil) || ([tableColumns count] == 0) || ([tableDatatypes count] == 0)) {
        [self QLP_setLastError:"QuickLite:createTable has failed because the supplied parameters are incorrect." withID:QLP_UnknownError];
        return NO;
    }
    
    NSSet* allowedDatatypes = [QuickLiteDatabase sharedQuickLiteDatatypes];
    NSSet* specifiedDatatypes = [NSSet setWithArray:tableDatatypes];
    
    if (![specifiedDatatypes isSubsetOfSet:allowedDatatypes]) {
        [self QLP_setLastError:"QuickLite:createTable has failed because one or more datatypes are not standard." withID:QLP_UnknownError];
        return NO;
    }
    
    // Make sure we have specified ROWID in the group of columns
    NSMutableArray* revisedColumns = [[NSMutableArray alloc]initWithArray:tableColumns];
    NSMutableArray* revisedDatatypes = [[NSMutableArray alloc]initWithArray:tableDatatypes];
    long ROWIDIndex = [self QLP_ROWIDPresenceLocation:tableColumns andDatatypes:tableDatatypes];
    
    if (ROWIDIndex != NSNotFound) {
        // Even though the ROWID has been specified by the user, we make sure the datatype is correct
        [revisedDatatypes replaceObjectAtIndex:ROWIDIndex withObject:QLRecordUIDDatatype];
    } else {
        // ROWID not found:add it manually
        [revisedColumns insertObject:QLRecordUID atIndex:0];
        [revisedDatatypes insertObject:QLRecordUIDDatatype atIndex:0];
    }

    BOOL transactionSetHere = NO;
    if (![self isTransactionActive])
        transactionSetHere = [self beginTransaction];
    
    BOOL everythingIsFine = YES;
    
    NSMutableString* sqlQuery;
    if (isTemporaryFlag)
        sqlQuery = [[NSMutableString alloc] initWithString:[NSString stringWithFormat:@"CREATE TEMPORARY TABLE %@(", table]];
    else
        sqlQuery = [[NSMutableString alloc] initWithString:[NSString stringWithFormat:@"CREATE TABLE %@(", table]];
    
    // Replace all QLString with TEXT when creating the real table. This solves the Manifest Typing issue.
    // For more info, check: http://www.mail-archive.com/sqlite-users@sqlite.org/msg08693.html
    NSMutableArray* tableCreationDatatypes = [NSMutableArray arrayWithArray:revisedDatatypes];
    int i, count = [revisedDatatypes count];
    
    for (i = 0; i < count; i++) {
        if ([[tableCreationDatatypes objectAtIndex:i]isEqualToString:QLString])
            [tableCreationDatatypes replaceObjectAtIndex:i withObject:@"TEXT"];
    }
    
    if ([self QLP_sqlString:sqlQuery withColumns:revisedColumns andDatatypes:tableCreationDatatypes]) {
        [sqlQuery appendString:@");"];

        everythingIsFine = [self QLP_performExecuteQuery:sqlQuery];
        
        if (everythingIsFine) {
            // Now add the entries to QLP_SchemaTable
            NSMutableArray* tableAndColumns = [[NSMutableArray alloc] init];
            
            for (i = 0; i < count; i++) {
                if (![self QLP_insertStringValues:[NSArray arrayWithObjects:table, [revisedColumns objectAtIndex:i], [revisedDatatypes objectAtIndex:i], nil] forColumns:[NSArray arrayWithObjects:QLP_TableIdentifier, QLP_ColumnIdentifier, QLP_DatatypeIdentifier, nil] inTable:QLP_SchemaTable]) {
                    everythingIsFine = NO;
                    break;
                }
            }
            
            // Cleanup
            [tableAndColumns release];
        }
    } else {
        [self QLP_setLastError:"QuickLite:createTable has failed while constructing the query." withID:QLP_UnknownError];
        everythingIsFine = NO;
    }
    
    if (transactionSetHere) {
        if (everythingIsFine)
            [self commitTransaction];
        else
            [self rollbackTransaction];
    }
    
    if (everythingIsFine)
        [self QLP_rebuildDatatypeCache];
    
    // Cleanup
    [revisedColumns release];
    [revisedDatatypes release];
    [sqlQuery release];
    
    return everythingIsFine;
}

- (BOOL)QLP_removeColumn:(NSString*)column fromTable:(NSString*)table
{
    // Obtain all current columns and datatypes for table
    NSArray* tableInfoDatatypes = [self datatypesForTable:table];
    
    if (tableInfoDatatypes == nil) {
        [self QLP_setLastError:"QuickLite:removeColumn has failed because tableInfoDatatypes is nil." withID:QLP_UnknownError];
        return NO;
    }
    
    NSArray* tableInfoColumns = [self columnsForTable:table];
    
    int index = [tableInfoColumns indexOfObject:column];
    
    if (index == NSNotFound) {
        [self QLP_setLastError:[[NSString stringWithFormat:@"QuickLite:removeColumn has failed because the column %@ doesn't exist.", column] UTF8String] withID:QLP_UnknownError];
        return NO;
    }
    
    // Add the new column and data type to the list
    NSMutableArray* tableColumns = [[NSMutableArray alloc] initWithArray:tableInfoColumns];
    NSMutableArray* tableDatatypes = [[NSMutableArray alloc] initWithArray:tableInfoDatatypes];
    [tableColumns removeObjectAtIndex:index];
    [tableDatatypes removeObjectAtIndex:index];
    
    BOOL transactionSetHere = NO;
    if (![self isTransactionActive])
        transactionSetHere = [self beginTransaction];
    
    // Create a backup table with the columns and datatypes
    BOOL everythingIsFine = YES;
    
    BOOL isTableTemporary = [[self temporaryTables] containsObject:table];
    if ([self QLP_createTable:[NSString stringWithFormat:@"%@_backup", table] withColumns:tableColumns andDatatypes:tableDatatypes isTemporary:isTableTemporary]) {
        // Insert all existing data
        NSMutableString* query = [NSMutableString stringWithString:[NSString stringWithFormat:@"INSERT INTO %@_backup(", table]];
        
        [self QLP_sqlString:query appendingTags:tableColumns];
        [query appendString:@") SELECT "];
        [self QLP_sqlString:query appendingTags:tableColumns];
        
        everythingIsFine = [self QLP_performExecuteQuery:[NSString stringWithFormat:@"%@ FROM %@;", query, table]];
        
        // Delete the old table
        if (![self dropTable:table])
            everythingIsFine = NO;
        
        // Create the new table with the columns and datatypes
        isTableTemporary = [[self temporaryTables] containsObject:table];
        if (![self QLP_createTable:table withColumns:tableColumns andDatatypes:tableDatatypes isTemporary:isTableTemporary])
            everythingIsFine = NO;
        
        // Copy the data from the backup table
        query = [NSMutableString stringWithString:[NSString stringWithFormat:@"INSERT INTO %@(", table]];
        
        [self QLP_sqlString:query appendingTags:tableColumns];
        [query appendString:@") SELECT "];
        [self QLP_sqlString:query appendingTags:tableColumns];
        
        everythingIsFine = [self QLP_performExecuteQuery:[NSString stringWithFormat:@"%@ FROM %@_backup;", query, table]];
        
        // Delete the backup table
        if (![self dropTable:[NSString stringWithFormat:@"%@_backup", table]])
            everythingIsFine = NO;
    } else {
        everythingIsFine = NO;
    }
    
    // Cleanup
    [tableColumns release];
    [tableDatatypes release];
    
    if (transactionSetHere) {
        if (everythingIsFine) {
            [self commitTransaction];
        } else {
            [self rollbackTransaction];
        }
    }
    
    if (everythingIsFine)
        [self QLP_rebuildDatatypeCache];
    
    return everythingIsFine;
}

- (void)QLP_rebuildDatatypeCache
{
    // Cleanup
    [QL_schema release];
    QL_schema = nil;
    
    NSArray* tables = [self QLP_flattenAllTables];
    if ([tables count] == 0)
        return;
    
    NSMutableDictionary* tempSchema = [[NSMutableDictionary alloc]init];
    BOOL everythingIsFine = YES;
    long i, count = [tables count];
    
    for (i = 0; i < count; i++) {
        NSString* table = [tables objectAtIndex:i];
        NSArray* columns = [self columnsForTable:table];
        NSArray* datatypes = [self datatypesForTable:table];
        if ((!table) || (!columns) || (!datatypes)) {
            everythingIsFine = NO;
            break;
        }
        
        // Build the dictionary
        NSMutableDictionary *tableDictionary = [[NSMutableDictionary alloc] init];
        int j, columnCount = [columns count];
        
        for (j = 0; j < columnCount; j++) {
            [tableDictionary setObject:[datatypes objectAtIndex:j] forKey:[columns objectAtIndex:j]];
        }
        
        [tempSchema setObject:tableDictionary forKey:table];
        
        // Cleanup...
        [tableDictionary release];
    }
    
    if (everythingIsFine)
        QL_schema = [[NSDictionary alloc]initWithDictionary:tempSchema];
    
    // Cleanup
    [tempSchema release];
}

- (BOOL)QLP_insertStringValues:(NSArray*)values forColumns:(NSArray*)columns inTable:(NSString*)table
{
    // Make sure we have specified ROWID in the group of columns
    NSMutableArray* revisedColumns = (NSMutableArray*)columns;
    
    // Escape all values except the one with type QLRecordUIDDatatype
    NSMutableArray* escapedValues = [[NSMutableArray alloc] init];
    int i, count = [revisedColumns count];
    
    for (i = 0; i < count; i++) {
        NSString* column = [revisedColumns objectAtIndex:i];
        NSString* value = [values objectAtIndex:i];
        NSString* escapedValue = nil;
        if (![self QLP_isColumnROWIDAlias:column forTable:table])
            escapedValue = [[NSString alloc]initWithFormat:@"'%@'", value];
        else
            escapedValue = [[NSString alloc]initWithFormat:@"%@", value];
        [escapedValues addObject:escapedValue];
        // Cleanup
        [escapedValue release];
    }
    
    NSMutableString* sqlQuery = [[NSMutableString alloc]initWithString:[NSString stringWithFormat:@"INSERT INTO %@(", table]];
    
    [self QLP_sqlString:sqlQuery appendingTags:revisedColumns];
    [sqlQuery appendString:@") VALUES("];
    [self QLP_sqlString:sqlQuery appendingTags:escapedValues];
    [sqlQuery appendString:@");"];
    BOOL insertWasOK = [self QLP_performExecuteQuery:sqlQuery];
    
    // Cleanup
    [escapedValues release];
    [sqlQuery release];
    
    return insertWasOK;
}

- (void)QLP_sqlString:(NSMutableString*)sqlString appendingTags:(NSArray*)tags quoteTags:(BOOL)flag 
{
    int i, count = [tags count];
    
    if (flag) {
        for (i = 0; i < count; i++) {
            NSString* tagName = [tags objectAtIndex:i];
            NSString* escapedValue = [[NSString alloc]initWithFormat:@"'%@'", tagName];
            
            [sqlString appendString:escapedValue];
            
            // Cleanup
            [escapedValue release];
            
            if (i != count - 1)
                [sqlString appendString:@","];
        }
    } else {
        [sqlString appendString:[tags componentsJoinedByString:@","]];
    }
}

- (void)QLP_sqlString:(NSMutableString*)sqlString appendingTags:(NSArray*)tags
{
    [self QLP_sqlString:sqlString appendingTags:tags quoteTags:NO];
}

- (BOOL)QLP_sqlString:(NSMutableString*)sqlString withColumns:(NSArray*)columns andDatatypes:(NSArray*)datatypes
{
    BOOL constructionSucceeded = YES;
    int i, count = [columns count];
    
    for (i = 0; i < count; i++) {
        NSString* column = [columns objectAtIndex:i];
        NSString* datatype = [datatypes objectAtIndex:i];
        
        if (datatype != nil) {
            // Some datatypes may be empty strings.
            // See QuickLiteDatabase's header file for more info on datatypesForTable:.
            NSString* columnAndDatatype = nil;
            
            if ([datatype isEqualToString:@""])
                columnAndDatatype = [[NSString alloc]initWithFormat:@"%@", column];
            else
                columnAndDatatype = [[NSString alloc]initWithFormat:@"%@ %@", column, datatype];
            
            [sqlString appendString:columnAndDatatype];
            
            // Cleanup
            [columnAndDatatype release];
            
            if (i != count - 1)
                [sqlString appendString:@","];
        } else {
            constructionSucceeded = NO;
        }
    }
    
    return constructionSucceeded;
}

- (long)QLP_ROWIDPresenceLocation:(NSArray*)tableColumns andDatatypes:(NSArray*)datatypes
{
    // First check if we have a datatype of type QLRecordUIDDatatype
    int i, count;
    long ROWIDIndex = NSNotFound;
    
    if (datatypes) {
        count = [datatypes count];
	
        for (i = 0; i < count; i++) {
            if ([[[datatypes objectAtIndex:i] uppercaseString] isEqualToString:QLRecordUIDDatatype]) {
                ROWIDIndex = i;
                break;
            }
        }
    }
    
    if (ROWIDIndex == NSNotFound) {
        // Make sure we have specified ROWID in the group of columns
        NSArray* reservedKeywords = [QuickLiteDatabase sharedROWIDKeywords];
        count = [tableColumns count];
        
        for (i = 0; i < count; i++) {
            int index = [reservedKeywords indexOfObject:[tableColumns objectAtIndex:i]];
            
            if (index != NSNotFound) {
                ROWIDIndex = index;
                break;
            }
        }
    }
    
    return ROWIDIndex;
}

- (BOOL)QLP_isColumnROWIDAlias:(NSString*)column forTable:(NSString*)table
{
    if ((column == nil) || (table == nil))
        return NO;
    
    if (QL_schema) {
        return [[[QL_schema objectForKey:table]objectForKey:column]isEqualToString:QLRecordUIDDatatype];
    } else {
        NSString* sqlQuery = [[NSString alloc]initWithFormat:@"SELECT %@ FROM %@ WHERE %@ = '%@' AND %@ = '%@';", QLP_DatatypeIdentifier, QLP_SchemaTable, QLP_TableIdentifier, table, QLP_ColumnIdentifier, column];
        QuickLiteCursor* cursor = [self QLP_performInternalQuickLiteQuery:sqlQuery];
        [sqlQuery release];
        
        NSString* columnFound = [[cursor rowAtIndex:0] valueForColumn:QLP_FullDatatypeIdentifier];
        
        return [columnFound isEqualToString:QLRecordUIDDatatype];
    }
    
    return NO;
}

- (NSString*)QLP_prefixWithDotDelimiter:(NSString*)tableAndColumn
{
    NSRange range = [tableAndColumn rangeOfString:@"." options:NSBackwardsSearch];
    if (range.location == NSNotFound)
        return tableAndColumn;
    
    return [tableAndColumn substringToIndex:range.location];
}

- (NSString*)QLP_suffixWithDotDelimiter:(NSString*)tableAndColumn
{
    NSRange range = [tableAndColumn rangeOfString:@"." options:NSBackwardsSearch];
    if (range.location == NSNotFound)
        return tableAndColumn;
    
    range.location++;
    range.length = [tableAndColumn length] - range.location;
    
    return [tableAndColumn substringWithRange:range];
}

- (void)QLP_installCommitCallback
{
    sqlite3_commit_hook( QL_sqliteDatabase, QLP_commitCallback, self);
}

- (void)QLP_QuickLiteDatabaseDidChangeNotification
{
    NSMutableDictionary* info = [[NSMutableDictionary alloc]init];
    
    [info setObject:[NSNumber numberWithLong:QL_processID] forKey:QLP_ProcessID];
    [info setObject:[self databasePath] forKey:QLDatabasePathIdentifier];
    [info setObject:[NSCalendarDate calendarDate] forKey:QLTimestampIdentifier];
    
    NSDistributedNotificationCenter* center = [NSDistributedNotificationCenter defaultCenter];
    
    // Fast user switching is only available in Panther (Mac OS X 10.3)
#if MAC_OS_X_VERSION_10_3 <= MAC_OS_X_VERSION_MAX_ALLOWED
    [center postNotificationName:QLP_QuickLiteDatabaseDidChangeNotification object:nil userInfo:info options:NSNotificationPostToAllSessions];
#else
    [center postNotificationName:QLP_QuickLiteDatabaseDidChangeNotification object:nil userInfo:info];
#endif
    
    // Cleanup
    [info release];
}

int QLP_commitCallback(void* qldb)
{
    [(QuickLiteDatabase*)qldb QLP_QuickLiteDatabaseDidChangeNotification];
    
    return QLSuccess;
}

@end