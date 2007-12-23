/*
 *  QuickLiteGlobalsPrivate.h
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

// Private section

typedef enum quicklite_datatypes {
	QL_RowID = 0,				// INTEGER PRIMARY KEY
	QL_String,				// NSString
        QL_Number,				// NSNumber
	QL_Boolean,				// NSNumber
	QL_DateTime,				// NSCalendarDate
	QL_Container,				// NSData
	QL_Unknown = NSNotFound,
} QLDatatype;

extern int const QLP_UnknownError;			// Some errors reported by SQLite do not have an error code

extern NSString * const QLP_TableIdentifier;
extern NSString * const QLP_ColumnIdentifier;
extern NSString * const QLP_DatatypeIdentifier;
extern NSString * const QLP_FullColumnIdentifier;
extern NSString * const QLP_FullDatatypeIdentifier;

extern NSString * const QLP_UUID;
extern int        const	QLP_UseDefaultCacheMethod;
extern NSString * const QLP_NullString;

extern NSString * const QLP_QuickLiteDatabaseDidChangeNotification;
extern NSString * const QLP_QuickLiteDatabaseDidCompactNotification;
extern NSString * const QLP_QuickLiteDatabaseDidCloseNotification;
extern NSString * const QLP_ProcessID;