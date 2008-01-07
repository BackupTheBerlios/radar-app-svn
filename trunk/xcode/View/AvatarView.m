//
//  AvatarView.m
//  Radar
//
//  Created by Daniel Reutter on 5/17/07.
//  Copyright 2007 Technische Universitaet Muenchen. All rights reserved.
//

#import "AvatarView.h"
#import "UserFactory.h"
#import "User.h"

@implementation AvatarView

- (id)initWithFrame:(NSRect)frameRect
{
	if ((self = [super initWithFrame:frameRect]) != nil) {
		// Add initialization code here
	}
	return self;
}

/// Draw the users contained by theUserFactory
/** This method draws the users in theUserFactory.
  * \todo This method needs maintenance.
  */
- (void)drawRect:(NSRect)rect
{
	NSRect bounds = [self bounds];
//	NSPoint p = bounds.origin;
	NSArray* theUsers = [theUserFactory allUsers];
	
	[[NSColor grayColor] set];
	[NSBezierPath fillRect:bounds];
	
	// TODO: Remove the following line
	unsigned i;
	unsigned j = [theUsers count];
	if (j == 0)
	{
		// No Personae to display
		return;
	}
	for (i = j; i > 0; --i)
	{
		NSPoint userPos = [[theUsers objectAtIndex: i-1] lastPosition];
		NSPoint coords = bounds.origin;
		srandomdev();
		
		while (userPos.x < 0.1)
		{
			userPos.x = ((float)(random()%100))/100.0;
		}
		
		userPos.y = 1.0 - [[theUsers objectAtIndex: i-1] score];
		
		[[theUsers objectAtIndex: i-1] setLastPosition: userPos];
		
		float xvalue = userPos.x - 0.5 * userPos.y * (userPos.x - 0.5);
		float yvalue = userPos.y * 0.5 * (2.5-userPos.y);		
		
		coords.x += xvalue * bounds.size.width;
		coords.y += yvalue * bounds.size.height;
		
		NSImage* theUserImage = [[theUsers objectAtIndex: i-1] valueForKey: @"theImage"];
		
		NSSize newSize = [theUserImage size];
		float sizeFactor = (100/newSize.width);
		sizeFactor *= 1.0-(yvalue/2.0);
		newSize.width *= sizeFactor;		
		newSize.height *= sizeFactor;
		
		coords.x -= newSize.width/2;
		
		[theUserImage setScalesWhenResized: YES];
		[theUserImage setSize: newSize];
		[theUserImage dissolveToPoint: coords fraction: 1];
	}
}

@end
