/*
 *  QuickLiteCursorPrivate.h
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

@interface QuickLiteCursor (Private)

// Private methods. Not available for development.

- (id)QLP_initWithDatabase:(QuickLiteDatabase*)database withQuery:(NSString*)inQuery cacheMethod:(QLCacheMethod)cacheMethod treatValuesAsString:(BOOL)treatAsString;

- (BOOL)QLP_setupCursor;
- (BOOL)QLP_cacheCursorColumns;
- (BOOL)QLP_cacheCursorDataTreatingValuesAsString:(BOOL)treatAsString;

// Obtain a value of a column at a given row
- (id)QLP_valueForColumn:(NSString*)tableAndColumn andRow:(unsigned long)rowIndex treatValuesAsString:(BOOL)flag;
- (id)QLP_valueFromCache:(NSString*)tableAndColumn;

- (void)QLP_initializeVM:(sqlite3_stmt**)sqliteVM withTableColumn:(NSString*)tableAndColumn andRow:(unsigned long)rowIndex;

// Set the value of a column at a given row
- (BOOL)QLP_setValue:(id)value forColumn:(NSString*)tableAndColumn forRow:(unsigned long)rowIndex;

// Obtain the value for a given column in a given row.
- (NSString*)QLP_stringForColumn:(NSString*)inColumnName andRow:(unsigned long)rowIndex;

// Obtain the RowUID of a table for the given index
- (NSString*)QLP_rowUIDInfoOfColumn:(NSString*)tableAndColumn forRow:(unsigned long)rowIndex;
- (NSString*)QLP_rowIDColumnForTable:(NSString*)table;
- (NSString*)QLP_rowIDColumnForColumn:(NSString*)tableAndColumn;

// Attempt to build and execute an update query with the given columns and values
- (BOOL)QLP_buildAndExecuteUpdateQueryWithRowID:(NSNumber*)rowUID withColumns:(NSArray*)columns andValues:(NSArray*)values forTable:(NSString*)table;

// Save, optionally deregistering the cursor and wrapping it within a transaction
- (BOOL)QLP_saveAndDeregisterCursor:(BOOL)doDeregisterCursor;
// Revert, optionally deregistering the cursor
- (void)QLP_revertAndDeregisterCursor:(BOOL)doDeregisterCursor;

- (id)QLP_objectFromSQLiteData:(const char*)data withColumn:(NSString*)tableAndColumn;

- (BOOL)QLP_validateValue:(id)value forColumn:(NSString*)tableAndColumn startAtIndex:(unsigned long)index;
- (BOOL)QLP_validateValue:(id)value forColumn:(NSString*)tableAndColumn;

- (void)QLP_adjustDictionaryValuesWithQuickEditData:(NSMutableDictionary*)values forRow:(unsigned long)rowIndex;

- (NSMutableArray*)QLP_removeObject:(id)value fromArray:(NSMutableArray*)array;

- (unsigned long)QLP_matchingRowWithValue:(id)value forColumn:(NSString*)tableAndColumn startAtIndex:(unsigned long)index comparisonMethod:(unsigned)method;
- (NSArray*)QLP_matchingRowsWithValue:(id)value forColumn:(NSString*)tableAndColumn comparisonMethod:(unsigned)method;

- (NSDictionary*)QLP_verifyCursorsForSetOperation:(QuickLiteCursor*)cursor;

@end