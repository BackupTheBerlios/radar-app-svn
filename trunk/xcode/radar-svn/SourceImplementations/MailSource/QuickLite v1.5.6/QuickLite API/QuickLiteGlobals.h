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

#import <Foundation/Foundation.h>

// SQLite uses this specifier for the first column, always of type INTEGER PRIMARY KEY
// As the SQLite documentation clearly states, inserting a NULL value for this column
// will generate a unique row id.

extern NSString * const QLRecordUID;			// SQLite's standard UID property
extern NSString * const QLRecordUIDDatatype;		// SQLite's standard UID property datatype

extern int const QLSuccess;                             // No error ID, as reported by SQLite
extern NSString * const QLP_SchemaTable;		// Private, reserved QuickLite table name to store datatypes

// Public notification sent when the schema has changed.
// When this notification is received, one can assume QuickLite has updated its cache,
// and the app can resume its normal course of operation.
extern NSString * const QLDatabasePathIdentifier;
extern NSString * const QLTimestampIdentifier;
extern NSString * const QLSQLStatementIdentifier;
extern NSString * const QLDatabaseHasChangedNotification;
extern NSString * const QLDatabaseHasSentSQLStatementNotification;

typedef enum quicklite_import_result {
    QLImportOK = 0,
    QLImportFilePathNotFound = 1,
    QLImportFilePathIsDirectory = 2,
    QLImportFilePathCouldNotBeOpened = 3,
    QLImportFileEncodingNotValid = 4,
    QLImportFileColumnsNotFound = 5,
    QLImportFileColumnEmpty = 6,
    QLImportFileTableNotFound = 7,
    QLImportFileColumnNameContainsSpace = 8,
    QLImportColumnsNonConforming = 9,
    QLImportDataNonConforming = 10,
    QLImportDataWithoutColumnDelimiter = 11,
    QLImportDataWithoutRecordDelimiter = 12,
    QLImportDataHasInvalidCharacter = 13,
    QLImportFileCouldNotCreateTable = 14,
    QLImportFileCouldNotClearTable = 15,
} QLImportResult;

extern NSString * const QLString;
extern NSString * const QLNumber;
extern NSString * const QLBoolean;
extern NSString * const QLDateTime;
extern NSString * const QLContainer;

typedef enum sqlite_synchronous_mode {
    SynchronousModeOff = 0,
    SynchronousModeNormal,
    SynchronousModeFull,
} QLSynchronousMode;

typedef enum sqlite_tempstore_mode {
    TempStoreModeDefault = 0,
    TempStoreModeFile,
    TempStoreModeMemory,
} QLTempStoreMode;

typedef enum quicklite_cache_method {
    CacheAllData = 1,
    CacheDataOnDemand,
    DoNotCacheData,
} QLCacheMethod;

typedef enum quicklite_set_ops {
    Union = 1,
    Minus,
    Intersect,
} QLSetOperation;