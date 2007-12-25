/*
 *  QuickLiteGlobals.h
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

#import "QuickLiteGlobals.h"
#import "sqlite3.h"

// SQLite uses this specifier for the first column, always of type INTEGER PRIMARY KEY
// As the SQLite documentation clearly states, inserting a NULL value for this column
// will generate a unique row id.

NSString * const QLRecordUID		= @"ROWID";
NSString * const QLRecordUIDDatatype	= @"INTEGER PRIMARY KEY";

int const QLSuccess			= SQLITE_OK;
int const QLP_UnknownError		= -1;

NSString * const QLString		= @"QLString";
NSString * const QLNumber		= @"QLNumber";
NSString * const QLBoolean		= @"QLBoolean";
NSString * const QLDateTime		= @"QLDateTime";
NSString * const QLContainer            = @"QLContainer";

NSString * const QLDatabasePathIdentifier			= @"QLDatabasePathIdentifier";
NSString * const QLTimestampIdentifier				= @"QLTimestampIdentifier";
NSString * const QLSQLStatementIdentifier			= @"QLSQLStatementIdentifier";
NSString * const QLDatabaseHasChangedNotification               = @"QLDatabaseHasChangedNotification";
NSString * const QLDatabaseHasSentSQLStatementNotification	= @"QLDatabaseHasSentSQLStatementNotification";

// Private section

NSString * const QLP_SchemaTable					= @"QLP_SchemaTable";
NSString * const QLP_TableIdentifier					= @"QLP_TableIdentifier";
NSString * const QLP_ColumnIdentifier					= @"QLP_ColumnIdentifier";
NSString * const QLP_DatatypeIdentifier					= @"QLP_DatatypeIdentifier";

NSString *	QLP_FullColumnIdentifier				= @"QLP_SchemaTable.QLP_ColumnIdentifier";
NSString *	QLP_FullDatatypeIdentifier				= @"QLP_SchemaTable.QLP_DatatypeIdentifier";

NSString *	QLP_UUID                                                = @"UUID";
int		QLP_UseDefaultCacheMethod                               = 0;
NSString *	QLP_NullString						= @"<null>";

NSString * const QLP_QuickLiteDatabaseDidChangeNotification		= @"QLP_QuickLiteDatabaseDidChangeNotification";
NSString * const QLP_QuickLiteDatabaseDidCompactNotification            = @"QLP_QuickLiteDatabaseDidCompactNotification";
NSString * const QLP_QuickLiteDatabaseDidCloseNotification              = @"QLP_QuickLiteDatabaseDidCloseNotification";
NSString * const QLP_ProcessID                                          = @"QLP_ProcessID";