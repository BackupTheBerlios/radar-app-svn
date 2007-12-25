/*
 *  QuickLiteRow.m
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

#import "QuickLiteRow.h"
#import "QuickLiteCursor.h"
#import "QuickLiteCursorPrivate.h"
#import "QuickLiteGlobalsPrivate.h"

@implementation QuickLiteRow

- (id)QLP_initWithCursor:(QuickLiteCursor*)cursor withRow:(unsigned long)rowIndex
{
    if (cursor == nil)
        return nil;
    
    if (![self init])
        return nil;
    
    QL_quickLiteCursor = [cursor retain];
    QL_rowIndex = rowIndex;
    
    return self;
}

- (id)init
{
    if (![super init])
        return nil;
    
    QL_quickLiteCursor = nil;
    QL_rowIndex = 0;
    
    return self;
}

- (void)dealloc
{
    [QL_quickLiteCursor release];
    
    [super dealloc];
}

- (NSString*)description
{
    NSArray* columns = [QL_quickLiteCursor columns];
    
    if ([columns count] == 0)
        return @"<The cursor is empty>";
    
    NSMutableString* tempValue = [NSMutableString string];
    int i, columnCount = [columns count];
    
    [tempValue appendString:[NSString stringWithFormat:@"Number of columns:%d\n", columnCount]];
    
    [tempValue appendString:@"Row # | "];
    
    // Append the columns
    for (i = 0; i < columnCount; i++) {
        if (i > 0)
            [tempValue appendString:@" | "];
        [tempValue appendString:[columns objectAtIndex:i]];
    }
    [tempValue appendString:@"\n"];
    
    [tempValue appendString:[NSString stringWithFormat:@"[%ld] ", QL_rowIndex]];
    
    for (i = 0; i < columnCount; i++) {
        if (i > 0)
            [tempValue appendString:@" | "];
        NSString* columnValue = [QL_quickLiteCursor QLP_valueForColumn:[columns objectAtIndex:i] andRow:QL_rowIndex treatValuesAsString:YES];
        if (columnValue != nil)
            [tempValue appendString:columnValue];
        else
            [tempValue appendString:QLP_NullString];
    }
    
    return tempValue;
}

#pragma mark// ==================================
#pragma mark// Accessor Methods
#pragma mark// ==================================

- (QuickLiteCursor*)cursor
{
    return QL_quickLiteCursor;
}

- (unsigned int)index
{
    return QL_rowIndex;
}

- (BOOL)setValue:(id)value forColumn:(NSString*)tableAndColumn
{
    return [QL_quickLiteCursor QLP_setValue:value forColumn:tableAndColumn forRow:QL_rowIndex];
}

- (NSString*)stringForColumn:(NSString*)tableAndColumn
{
    return [QL_quickLiteCursor QLP_stringForColumn:tableAndColumn andRow:QL_rowIndex];
}

- (id)valueForColumn:(NSString*)tableAndColumn
{
    return [QL_quickLiteCursor valueForColumn:tableAndColumn andRow:QL_rowIndex];
}

- (BOOL)boolValueForColumn:(NSString*)tableAndColumn
{
    return [QL_quickLiteCursor boolValueForColumn:tableAndColumn andRow:QL_rowIndex];
}

- (int)intValueForColumn:(NSString*)tableAndColumn
{
    return [QL_quickLiteCursor intValueForColumn:tableAndColumn andRow:QL_rowIndex];
}

- (long long)longLongValueForColumn:(NSString*)tableAndColumn
{
    return [QL_quickLiteCursor longLongValueForColumn:tableAndColumn andRow:QL_rowIndex];
}

- (double)doubleValueForColumn:(NSString*)tableAndColumn
{
    return [QL_quickLiteCursor doubleValueForColumn:tableAndColumn andRow:QL_rowIndex];
}

- (const unsigned char*)textValueForColumn:(NSString*)tableAndColumn
{
    return [QL_quickLiteCursor textValueForColumn:tableAndColumn andRow:QL_rowIndex];
}

- (NSDictionary*)values
{
    return [QL_quickLiteCursor valuesForRow:QL_rowIndex];
}

@end