/*
 *  QuickLiteDatabaseExtras.h
 *  A lightweight Cocoa wrapper for SQLite
 *  
 *  Written by Tito Ciuro (20-May-2004)

	Copyright (c) 2004, Tito Ciuro
	All rights reserved.

	Redistribution and use in source and binary forms, with or without modification, are permitted
	provided that the following conditions are met:
	
	¥  	Redistributions of source code must retain the above copyright notice, this list of conditions
		and the following disclaimer.
	¥  	Redistributions in binary form must reproduce the above copyright notice, this list of conditions
		and the following disclaimer in the documentation and/or other materials provided with the distribution.
	¥  	Neither the name of Tito Ciuro nor the names of its contributors may be used to endorse or promote
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

@interface QuickLiteDatabase (QuickLiteDatabaseExtras)

+ (NSArray*)sharedROWIDKeywords;
+ (NSSet*)sharedQuickLiteDatatypes;

#pragma mark Transaction Methods

/// In SQLite version 3.0.8 and later, transactions can be deferred, immediate, or exclusive.
///
/// Deferred means that no locks are acquired on the database until the database is first accessed. Thus with a deferred
/// transaction, the BEGIN statement itself does nothing. Locks are not acquired until the first read or write operation.
/// The first read operation against a database creates a SHARED lock and the first write operation creates a RESERVED lock.
/// Because the acquisitionof locks is deferred until they are needed, it is possible that another thread or process could
/// create a separate transaction and write to the database after the BEGIN on the current thread has executed.
///
/// If the transaction is immediate, then RESERVED locks are acquired on all databases as soon as the BEGIN command is executed,
/// without waiting for the database to be used. After a BEGIN IMMEDIATE, you are guaranteed that no other thread or process
/// will be able to write to the database or do a BEGIN IMMEDIATE or BEGIN EXCLUSIVE. Other processes can continue to read from
/// the database, however.
///
/// An exclusive transaction causes EXCLUSIVE locks to be acquired on all databases. After a BEGIN EXCLUSIVE, you are guaranteed
/// that no other thread or process will be able to read or write the database until the transaction is complete.
///
/// The default behavior for SQLite version 3.0.8 is a deferred transaction. For SQLite version 3.0.0 through 3.0.7,
/// deferred is the only kind of transaction available. For SQLite version 2.8 and earlier, all transactions are
/// exclusive.
///
/// For more info, check: http://www.sqlite.org/lang.html#transaction
///
/// 'beginTransaction' exists for backward-compatibility reasons. It simply calls 'beginDeferredTransaction', which is
/// the default transaction used by SQLite.

- (BOOL)beginTransaction;
- (BOOL)beginDeferredTransaction;
- (BOOL)beginImmediateTransaction;
- (BOOL)beginExclusiveTransaction;

- (BOOL)commitTransaction;
- (BOOL)rollbackTransaction;

#pragma mark Table Methods

- (BOOL)createTable:(NSString*)table withColumns:(NSArray*)columns andDatatypes:(NSArray*)datatypes;
- (BOOL)createTemporaryTable:(NSString*)table withColumns:(NSArray*)columns andDatatypes:(NSArray*)datatypes;
- (BOOL)copyTable:(NSString*)src toTable:(NSString*)dst;
- (BOOL)dropTable:(NSString*)table;

- (BOOL)addColumn:(NSString*)column withDataType:(NSString*)datatype toTable:(NSString*)table;
- (BOOL)removeColumn:(NSString*)column fromTable:(NSString*)table;
- (NSArray*)tableInfo:(NSString*)table;

- (BOOL)insertValues:(NSArray*)values forColumns:(NSArray*)columns inTable:(NSString*)table;
- (BOOL)updateValues:(NSArray*)values forColumns:(NSArray*)columns withRowUID:(NSNumber*)rowUID inTable:(NSString*)table;
- (BOOL)deleteRowWithUID:(NSNumber*)rowUID inTable:(NSString*)table;
- (BOOL)deleteRowsWithUIDObjects:(NSArray*)rowUIDs inTable:(NSString*)table;
- (BOOL)deleteRowsWithValue:(id)value forColumn:(NSString*)column inTable:(NSString*)table;
- (BOOL)deleteAllRowsInTable:(NSString*)table;

- (unsigned long)rowCountInTable:(NSString*)table;

- (BOOL)createIndexForColumn:(NSString*)column inTable:(NSString*)table isUnique:(BOOL)flag;
- (void)dropIndex:(NSString*)indexName;

#pragma mark Private Methods

- (BOOL)QLP_beginTransactionMode:(NSString*)sqlQuery;
- (BOOL)QLP_createTable:(NSString*)table withColumns:(NSArray*)tableColumns andDatatypes:(NSArray*)tableDatatypes isTemporary:(BOOL)isTemporaryFlag;
- (BOOL)QLP_removeColumn:(NSString*)column fromTable:(NSString*)table;
- (void)QLP_rebuildDatatypeCache;
- (BOOL)QLP_insertStringValues:(NSArray*)values forColumns:(NSArray*)columns inTable:(NSString*)table;

- (void)QLP_sqlString:(NSMutableString*)sqlString appendingTags:(NSArray*)tags quoteTags:(BOOL)flag;
- (void)QLP_sqlString:(NSMutableString*)sqlString appendingTags:(NSArray*)columns;
- (BOOL)QLP_sqlString:(NSMutableString*)sqlString withColumns:(NSArray*)columns andDatatypes:(NSArray*)datatypes;

- (long)QLP_ROWIDPresenceLocation:(NSArray*)tableColumns andDatatypes:(NSArray*)datatypes;
- (BOOL)QLP_isColumnROWIDAlias:(NSString*)column forTable:(NSString*)table;

- (NSString*)QLP_prefixWithDotDelimiter:(NSString*)tableAndColumn;
- (NSString*)QLP_suffixWithDotDelimiter:(NSString*)tableAndColumn;

- (void)QLP_installCommitCallback;
- (void)QLP_QuickLiteDatabaseDidChangeNotification;

@end