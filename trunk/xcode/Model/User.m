//
//  User.m
//  Radar
//
//  Created by Daniel Reutter on 5/3/07.
//  Copyright 2007 Technische Universitaet Muenchen. All rights reserved.
//

#import "User.h"


@implementation User

- (id) init
{
	if (self=[super init])
	{
		theName = nil;
		theInfo = nil;
		theImage = nil;
		theSource = nil;
		theLastPosition.x = 0.0;
		theLastPosition.y = 0.0;
	}
	return self;
}

- (id) initWithName:	(NSString*) aName
{
	if (self = [self init])
	{
		theName = [aName copy];
	}
	return self;
}

- (id) initWithName:	(NSString*) aName
		withImage:		(NSImage*) anImage
{
	if (self = [self initWithName:aName])
	{
		theImage = [anImage copy];
		[theImage setDataRetained: YES];
	}
	return self;
}

- (id) initWithName:	(NSString*) aName 
		withInfo:		(NSString*) anInfo 
		withImage:		(NSImage*) anImage 
		withSource:		(id) aSource
{
	if (self = [self initWithName:aName withImage:anImage])
	{
		theInfo = [anInfo copy];
		theSource = [aSource copy];
	}
	return self;
}

- (void) setScore: (float) newScore
{
	theScore = newScore;
}

- (float) score
{
	return theScore;
}

- (void) setLastPosition: (NSPoint) newPos
{
	theLastPosition = newPos;
}
- (NSPoint) lastPosition
{
	return theLastPosition;
}

- (NSComparisonResult)compareWith: (id) otherUser
{
	if ([self score] < [otherUser score]) return NSOrderedDescending;
	if ([self score] > [otherUser score]) return NSOrderedAscending;
	return NSOrderedSame;
}

- (id) initWithDictionary: (NSDictionary*) aDict
{
	if (self = [self initWithName: [aDict objectForKey: @"Name"]
						 withInfo: [aDict objectForKey: @"Info"]
						withImage: [[NSImage alloc] initWithData: [aDict objectForKey: @"Image"]]
					   withSource: [aDict objectForKey: @"Source"]])
	{
	}
	return self;
}

- (NSDictionary*) dictionary
{
	return [NSDictionary dictionaryWithObjectsAndKeys: theName, @"Name", theInfo, @"Info", [theImage TIFFRepresentation], @"Image", theSource, @"Source", nil];

	NSMutableDictionary* theDict = [[NSMutableDictionary alloc] initWithCapacity: 4];
	[theDict insertValue: theName inPropertyWithKey: @"Name"];
	[theDict insertValue: theInfo inPropertyWithKey: @"Info"];
	[theDict insertValue: [[NSBitmapImageRep imageRepWithData: [theImage TIFFRepresentation]] representationUsingType: NSPNGFileType properties: nil]
	   inPropertyWithKey: @"Image"];
	[theDict insertValue: theSource inPropertyWithKey: @"Source"];	
}

@end
