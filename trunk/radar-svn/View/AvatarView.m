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
		return;
	}
	for (i = j; i > 0; --i)
	{
		NSPoint coords = bounds.origin;
		
		float xvalue = (float)i / j; // The x position in context
		xvalue = 0.1 + 0.2 * (i % 5);
		float yvalue = [[theUsers objectAtIndex: i-1] score];
		
		yvalue = 1.0 - yvalue; // The higher the more important the less away from the bottom...
		
		xvalue -= 0.5 * yvalue * (xvalue - 0.5);
		yvalue *= 0.5 * (2.5-yvalue);

		coords.x += xvalue * bounds.size.width;
		coords.y += yvalue * bounds.size.height;
		
		NSImage* theUserImage = [[theUsers objectAtIndex: i-1] valueForKey: @"theImage"];
		
		NSSize newSize = [theUserImage size];
		float sizeFactor = (100/newSize.width);
		sizeFactor *= 1.0-(yvalue/2.0);
		newSize.width *= sizeFactor;		
		newSize.height *= sizeFactor;
		
//		[[theUsers objectAtIndex: i-1] setValue: coords forKey: @"theLastPosition"];
		
		coords.x -= newSize.width/2;
		
		[theUserImage setScalesWhenResized: YES];
		[theUserImage setSize: newSize];
		[theUserImage dissolveToPoint: coords fraction: 1];
	}
}

@end
