/*
 *  QuickLiteCursor.h
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

#import <Foundation/Foundation.h>
#import "sqlite3.h"

#import "QuickLiteDatabase.h"
#import "QuickLiteRow.h"

@class QuickLiteDatabase, QuickLiteRow;

@interface QuickLiteCursor : NSObject
{
    QuickLiteDatabase*      QL_quickLiteDatabase;
    NSString*               QL_sqlQuery;
    BOOL                    QL_treatAsString;
    sqlite3_stmt*           QL_sqliteVM;

    NSSet*                  QL_cacheTables;     /// Series of tables found in the cursor
    NSSet*                  QL_cacheColumns;    /// Series of tableColumns found in the cursor
    NSMutableArray*         QL_cache;           /// Series of dictionaries containing the data cached
    NSMutableDictionary*    QL_cacheEdits;      /// Series of dictionaries, with Key --> table; Value --> {Key --> tableAndColumn; Value --> <data>}
    NSMutableArray*         QL_cacheInserts;    /// Series of dictionaries containing the new, uncommited data
    NSMutableDictionary*    QL_cacheDeletes;    /// Series of table.column:rowUID
    QLCacheMethod           QL_cacheMethod;     /// Cache method to be used by default
}

    /// Useful to extract the cursor contents
- (NSString*)description;
- (NSString*)fullDescription;
- (NSString*)fullDescription:(unsigned long)numberOfRows;

    /// Find out whether the database has any unsaved changes.
- (BOOL)hasUnsavedChanges;

    /// Save the cache. It will requery again, to sync with the database
- (BOOL)save;

    /// Discard all changes. It will requery, to sync with the database
- (void)revert;

    /// Refresh the cursor. Basically, it issues the same query again, to pick up any possible
    /// changes made by other processes/threads. This method *does not* clear the cache (edits,
    /// inserts and/or deletes).
- (void)refresh;

#pragma mark Accessor Methods

    /// Obtain the query which generated the cursor.
- (NSString*)sqlQuery;

    /// Obtain the number of rows included in the cursor.
- (unsigned long)rowCount;

    /// Obtain the range of the inserted rows. If there are none, returns a range of {NSNotFound, 0}.
- (NSRange)rangeOfInsertedRows;

    /// Obtain the number of columns included in the cursor.
- (unsigned int)columnCount;

    /// Obtain all tables contained in the cursor
- (NSArray*)tables;

    /// Obtain the names of the columns included in the cursor.
- (NSArray*)columns;

    /// Obtain the names of the columns for a given table which are present in the cursor.
- (NSArray*)columnsForTable:(NSString*)table;

    /// Set the value for a given column
- (BOOL)setValue:(id)value forColumn:(NSString*)tableAndColumn;

    /// Get the value for a given column. If the value is NULL, [NSNull null] is returned.
- (id)valueForColumn:(NSString*)tableAndColumn andRow:(unsigned long)rowIndex;

    /// If the cursor has been created using DoNotCacheData, the folowing methods can be used
    /// to quickly access their scalar values, which will avoid creating NS-type objects.
    /// If CacheDataOnDemand has been used to create the cursor, the object may be already in
    /// the cache. In this case the scalar is returned from the cached object.
- (BOOL)boolValueForColumn:(NSString*)tableAndColumn andRow:(unsigned long)rowIndex;
- (int)intValueForColumn:(NSString*)tableAndColumn andRow:(unsigned long)rowIndex;
- (long long)longLongValueForColumn:(NSString*)tableAndColumn andRow:(unsigned long)rowIndex;
- (double)doubleValueForColumn:(NSString*)tableAndColumn andRow:(unsigned long)rowIndex;
- (const unsigned char*)textValueForColumn:(NSString*)tableAndColumn andRow:(unsigned long)rowIndex;

    /// Remove *all* UIDs referenced in the row at the specified index
- (BOOL)removeAllRowUIDsAtIndex:(unsigned long)rowIndex;

    /// Remove *all* UIDs referenced in the row at the specified indexes.
    /// *** IMPORTANT ***: the indexes must be objects of type NSNumber.
- (BOOL)removeAllRowUIDsAtIndexes:(NSArray*)rowIndexes;

#pragma mark Cursor Methods

    /// Obtain a row object for a given index
- (QuickLiteRow*)rowAtIndex:(unsigned)index;

    /// Obtain all values for a given column.
    /// If the value of an object is NULL, [NSNull null] is instantiated.
- (NSArray*)valuesForColumn:(NSString*)tableAndColumn;

    /// Obtain all values for a given row.
    /// If the value of an object is NULL, [NSNull null] is instantiated.
- (NSDictionary*)valuesForRow:(unsigned long)rowIndex;

    /// Add new data to a cursor. All columns must exist in the cursor.
- (BOOL)insertRowWithValues:(NSArray*)values forColumns:(NSArray*)columns;

    /// Obtain the deleted rowUIDs. It returns a dictionary with the affected tables (key) and
    /// a set (value) with all rowUIDs marked for deletion.
    /// The keys are stored in the format: <table name>.ROWID
    ///
    /// Example:
    ///     0 : <CFString 0x5e0f40 [0xa01900e0]>{contents = "address.ROWID"}
    ///             <CFSet 0x5e8050 [0xa01900e0]>{count = 3, capacity = 4, values = (
    ///                 1 : <CFNumber 0x5e8160 [0xa01900e0]>{value = +1, type = kCFNumberSInt32Type}
    ///                 2 : <CFNumber 0x5e8080 [0xa01900e0]>{value = +2, type = kCFNumberSInt32Type}
    ///                 3 : <CFNumber 0x5e8190 [0xa01900e0]>{value = +3, type = kCFNumberSInt32Type}
    ///             )}
    ///     2 : <CFString 0x5e0f90 [0xa01900e0]>{contents = "country.ROWID"}
    ///             <CFSet 0x5e80e0 [0xa01900e0]>{count = 1, capacity = 4, values = (
    ///                 1 : <CFNumber 0x5e7fd0 [0xa01900e0]>{value = +1, type = kCFNumberSInt32Type}
    ///             )}
    ///     )}
- (NSDictionary*)deletedRowUIDs;

    /// Obtain the modified rowUIDs. It returns a dictionary with the table (key) and
    /// the array of rowUIDs (value).
- (NSDictionary*)modifiedRowUIDs;

    /// Matching rows
    /// You can find the first match for a given column starting at a given index, or obtain a series of row indexes
    /// which contain a given value in a given column.
    ///
    /// The comparison mechanism used in the 'matchingRow(s)' family of methods is the following:
    ///
    /// Datatype        Comparison
    /// ********        **********
    /// QL_String:      - (NSComparisonResult)compare:(NSString *)aString options:(unsigned)mask
    /// QL_Number:      - (BOOL)isEqualToNumber:(NSNumber *)aNumber
    /// QL_Boolean:     - (BOOL)isEqualToNumber:(NSNumber *)aNumber
    /// QL_DateTime:    - (BOOL)isEqualToDate:(NSDate *)otherDate
    /// QL_Container:   - (BOOL)isEqualToData:(NSData *)other
    ///
    /// Notes:
    ///
    /// - 'comparisonMethod' only makes sense with objects of type QL_String, since only NSString supports
    /// the following supported comparison methods: NSCaseInsensitiveSearch, NSLiteralSearch, NSBackwardsSearch, NSAnchoredSearch
    /// NSBackwardsSearch, and NSNumericSearch. The default mode is 'NSLiteralSearch'.
    ///
    /// You can obtain each row separately by calling something like: [myCursor rowAtIndex:[[rows objectAtIndex:myIndex]unsignedIntValue]].
    /// The main reason to return an NSNumber instead of a QuickLiteRow has to do with memory. Matching values could potentially return
    /// many rows, which would have to be instantiated all at once. Instead, we do that lazily, deferring it to when it's actually needed.

    /// Find the first row matching a value in a given column.
    /// Starts at index 0.
- (unsigned long)matchingRowWithValue:(id)value forColumn:(NSString*)tableAndColumn;

    /// Find the first row matching a value in a given column.
    /// Starts at a given index.
- (unsigned long)matchingRowWithValue:(id)value forColumn:(NSString*)tableAndColumn startAtIndex:(unsigned long)index;

    /// Find the first row matching a value in a given column.
    /// Starts at a given index.
    /// Overrides 'NSLiteralSearch' with the comparison method supplied.
- (unsigned long)matchingRowWithValue:(id)value forColumn:(NSString*)tableAndColumn startAtIndex:(unsigned long)index comparisonMethod:(unsigned)method;

    /// Find the row indexes matching a value in a given column.
- (NSArray*)matchingRowsWithValue:(id)value forColumn:(NSString*)tableAndColumn;

    /// Find the row indexes matching a value in a given column.
    /// Overrides 'NSLiteralSearch' with the comparison method supplied.
- (NSArray*)matchingRowsWithValue:(id)value forColumn:(NSString*)tableAndColumn comparisonMethod:(unsigned)method;

    /// Find the row indexes matching a series of values in a given column.
- (NSArray*)matchingRowsWithValues:(NSArray*)values forColumn:(NSString*)tableAndColumn;

    /// Find the row indexes matching a series of values in a given column.
    /// Overrides 'NSLiteralSearch' with the comparison method supplied.
- (NSArray*)matchingRowsWithValues:(NSArray*)values forColumn:(NSString*)tableAndColumn comparisonMethod:(unsigned)method;

    /// Perform set operations between two cursors.
    /// *** IMPORTANT ***:
    ///     1) Only one table must be referenced in any of the two cursors
    ///     2) The same table must exist in the two cursors
    ///     3) The ROWUID column must be present in the two cursors
    /// If the result set is empty, an empty cursor is created. Otherwise, a new
    /// cursor is created with the ROWUIDs referenced. In an error occurs, nil is returned.
- (QuickLiteCursor*)unionCursor:(QuickLiteCursor*)cursor;
- (QuickLiteCursor*)unionCursor:(QuickLiteCursor*)cursor cacheMethod:(QLCacheMethod)cacheMethod;
- (QuickLiteCursor*)minusCursor:(QuickLiteCursor*)cursor;
- (QuickLiteCursor*)minusCursor:(QuickLiteCursor*)cursor cacheMethod:(QLCacheMethod)cacheMethod;
- (QuickLiteCursor*)intersectCursor:(QuickLiteCursor*)cursor;
- (QuickLiteCursor*)intersectCursor:(QuickLiteCursor*)cursor cacheMethod:(QLCacheMethod)cacheMethod;

@end