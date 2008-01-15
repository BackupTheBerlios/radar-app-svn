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
#import "Preferences.h"
#import "Debug.h"

#define AVATARVIEW_ARYUSERPOSITION 0
#define AVATARVIEW_ARYSIZE 1
#define AVATARVIEW_ARYREALPOSITION 2

@implementation AvatarView

- (id)initWithFrame:(NSRect)frameRect
{
	if ((self = [super initWithFrame:frameRect]) != nil) {
		// Add initialization code here
		theAvatarPositions = [NSDictionary dictionary];
		[theAvatarPositions retain];
	}
	return self;
}

/// Draw the users contained by theUserFactory
/** This method draws the users in theUserFactory.
  * \todo This method needs maintenance.
  */
- (void)drawRect:(NSRect)rect
{
	DSetContext(@"Drawing Users");
	NSArray* theUsers = [theUserFactory allUsers];
	
	[self removeAllToolTips];
	
	unsigned j = [theUsers count];
	if (j == 0)
	{
		// No Personae to display
		return;
	}	
	unsigned i;
		
	NSRect bounds = [self bounds];
	
	DLog(@"About to load the actual avatars");
	
	NSMutableDictionary* positions = [NSMutableDictionary dictionaryWithCapacity: [theUsers count]];
		
//	DLog(@"Actual avatars loaded: %@", actualAvatars);
	
//	DLog(@"theDisplayedAvatars = %@", theDisplayedAvatars);
	
	[[NSColor grayColor] set];
	[NSBezierPath fillRect:bounds];
	srandomdev(); // Initialize the random generator
	
	for (i = j; i > 0; --i)
	{
		User* theUser = [theUsers objectAtIndex: i-1];
		DLog(@"Displaying User %d", i-1);
		//NSPoint userPos = [[theUsers objectAtIndex: i-1] lastPosition];
		NSPoint coords = bounds.origin;
		NSPoint userPos;
		userPos.x = 0.0;
		userPos.y = 0.0;
		
//		if ([[theDisplayedAvatars objectForKey: [theUser description]] isKindOfClass: [NSString class]])
//		{
//			DLog(@"Getting the last user information");
//			userPos = NSPointFromString([[theDisplayedAvatars objectForKey: [theUser description]] objectAtIndex: AVATARVIEW_ARYUSERPOSITION]);
//		}
		
		userPos = [theUser lastPosition];
		
		while ((userPos.x < 0.1) || (userPos.x > 1.0))
		{
			userPos.x = ((float)(random()%100))/100.0;
		}
		
		userPos.y = 1.0 - [theUser score];
		
		[theUser setLastPosition: userPos];
		
		float xvalue = userPos.x - 0.5 * userPos.y * (userPos.x - 0.5);
		float yvalue = userPos.y * 0.5 * (2.5-userPos.y);		
		
		coords.x += xvalue * bounds.size.width;
		coords.y += yvalue * bounds.size.height;
		
		NSImage* theUserImage = [[theUser valueForKey: @"theImage"] copy];
		
		NSSize newSize = [theUserImage size];

		NSSize maxSize = [thePreferences maxPersonaImageSize];
		
		if ([thePreferences retainPersonaImageRatio])
		{			
			float widthSizeFactor = (maxSize.width/newSize.width);
			float heightSizeFactor = (maxSize.height/newSize.height);
			float sizeFactor = widthSizeFactor<heightSizeFactor?widthSizeFactor:heightSizeFactor;
			if ((sizeFactor < 1.0) || [thePreferences makePersonaImageBigger])
			{
				newSize.width *= sizeFactor;
				newSize.height *= sizeFactor;
			}
		}
		else
		{
			if ((newSize.width > maxSize.width) || [thePreferences makePersonaImageBigger])
			{
				newSize.width = maxSize.width;
			}
			if ((newSize.height > maxSize.height) || [thePreferences makePersonaImageBigger])
			{
				newSize.height = maxSize.height;
			}
				
		}
		
		newSize.width *= 1.0-(yvalue/2.0);
		newSize.height *= 1.0-(yvalue/2.0);
		
		coords.x -= newSize.width/2;
		
		[theUserImage setScalesWhenResized: YES];
		[theUserImage setSize: newSize];
		[theUserImage dissolveToPoint: coords fraction: 1];
		
		NSRect posAndSize;
		posAndSize.origin = coords;
		posAndSize.size = newSize;
		
		[positions setObject: theUser
					  forKey: NSStringFromRect(posAndSize)];
		[self addToolTipRect: posAndSize
					   owner: [theUser valueForKey: @"theName"]
					userData: nil];
	}
	
	[theAvatarPositions release];
	theAvatarPositions = [NSDictionary dictionaryWithDictionary: positions];
	[theAvatarPositions retain];
}

- (void) mouseDown: (NSEvent*) theEvent
{
	DSetContext(@"MouseDownEvent");
	DLog(@"Mouse down event: %@", theEvent);
	unsigned i;
	NSPoint loc = [theEvent locationInWindow];
	NSArray* theKeys = [theAvatarPositions allKeys];
	
	for (i = 0; i < [theKeys count]; ++i)
	{
		if (NSPointInRect(loc, NSRectFromString([theKeys objectAtIndex: i])))
		{
			DLog(@"Clicked on %@", [[theAvatarPositions valueForKey: [theKeys objectAtIndex: i]] valueForKey: @"theName"]);
		}
	}
}

- (IBAction) resetPersonae: (id) sender
{
	[theUserFactory shufflePersonaPositions: sender];
	[self display];
}

@end
