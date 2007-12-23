/*
 *  QuickLiteRow.h
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
#import "QuickLiteCursor.h"

@class QuickLiteDatabase;

@interface QuickLiteRow : NSObject
{
    QuickLiteCursor*	QL_quickLiteCursor;
    unsigned int	QL_rowIndex;
}

    // Useful to extract the cursor contents
- (NSString*)description;

#pragma mark Accessor Methods

    // Find out whether the cursor is still attached to the database
- (QuickLiteCursor*)cursor;

    // Find out the cursor index which this row represents
- (unsigned int)index;

    // Set the value for a given column
- (BOOL)setValue:(id)value forColumn:(NSString*)tableAndColumn;

    // Obtain an NS*-type object.  If the value is NULL, [NSNull null] is instantiated.
- (id)valueForColumn:(NSString*)tableAndColumn;

    /// If the cursor has been created using DoNotCacheData, the folowing methods can be used
    /// to quickly access their scalar values, which will avoid creating NS-type objects.
    /// If CacheDataOnDemand has been used to create the cursor, the object may be already in
    /// the cache. In this case the scalar is returned from the cached object.
- (BOOL)boolValueForColumn:(NSString*)tableAndColumn;
- (int)intValueForColumn:(NSString*)tableAndColumn;
- (long long)longLongValueForColumn:(NSString*)tableAndColumn;
- (double)doubleValueForColumn:(NSString*)tableAndColumn;
- (const unsigned char*)textValueForColumn:(NSString*)tableAndColumn;

    // Obtain an NSString.  If the value is NULL, [NSNull null] is instantiated.
- (NSString*)stringForColumn:(NSString*)tableAndColumn;

    // Obtain all values for a given row. If the value of an object is NULL, [NSNull null] is instantiated.
- (NSDictionary*)values;

@end