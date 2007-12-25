/*
 *  QuickLiteDatabasePrivate.h
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
#import "QuickLiteCursor.h"
#import "QuickLiteGlobalsPrivate.h"

@interface QuickLiteDatabase (Private)

// Private methods. Not available for development.

- (sqlite3*)QLP_sqliteDatabase;

- (void)QLP_sendSQLStatement:(NSString*)sql;

- (BOOL)QLP_performExecuteQuery:(NSString*)sqlQuery;
- (BOOL)QLP_performExecuteQuery:(NSString*)sqlQuery saveSQLStatement:(BOOL)saveSQL;
- (QuickLiteCursor*)QLP_performInternalQuickLiteQuery:(NSString*)sqlQuery;
- (QuickLiteCursor*)QLP_performInternalQuickLiteQuery:(NSString*)sqlQuery cacheMethod:(QLCacheMethod)cacheMethod;
- (QuickLiteCursor*)QLP_performInternalQuickLiteQuery:(NSString*)sqlQuery cacheMethod:(QLCacheMethod)cacheMethod treatValuesAsString:(BOOL)treatAsString;
- (QuickLiteCursor*)QLP_performQuery:(NSString*)sqlQuery cacheMethod:(QLCacheMethod)cacheMethod treatValuesAsString:(BOOL)treatAsString saveSQLStatement:(BOOL)saveSQL;

- (QLDatatype)QLP_datatypeForColumn:(NSString*)tableAndColumn;
- (QLDatatype)QLP_datatypeForTable:(NSString*)table column:(NSString*)column;

- (BOOL)QLP_isArray:(NSArray*)source inArray:(NSArray*)target;

- (void)QLP_setLastError:(const char*)sqliteErrorString withID:(int)errorID;

- (QLImportResult)QLP_isImportFileAvailable:(NSString*)filePath;
- (void)QLP_decodeQuantum:(unsigned char *)dest andSource:(const char *)src;

- (void)QLP_registerModifiedCursor:(QuickLiteCursor*)cursor;
- (void)QLP_deregisterModifiedCursor:(QuickLiteCursor*)cursor;

- (void)QLP_setFullColumnNamesEnabled;

- (void)QLP_logIfInDebugMode:(SEL)cmd forClass:(Class)aClass;
- (void)QLP_logIfInDebugMode:(NSString*)string;

- (NSArray*)QLP_flattenAllTables;

- (void)QLP_executeSingleSQLStatement:(NSString*)sqlString;

@end