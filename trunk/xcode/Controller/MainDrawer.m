//
//  MainDrawer.m
//  Radar
//
//  Created by Daniel Reutter on 30.05.07.
//  Copyright 2007 Technische Universitaet Muenchen. All rights reserved.
//

#import "MainDrawer.h"


@implementation MainDrawer

- (void) awakeFromNib
{
	if ([theDrawer state])
	{
		[theDrawerButton setState: NSOffState];
	}
	else
	{
		[theDrawerButton setState: NSOnState];
	}
}

// Drawer Notification Handling
- (void) drawerDidClose: (NSNotification*)notification
{
	if ([notification object] == theDrawer)
	{
		[theDrawerButton setState: NSOnState];
	}
}

- (void) drawerDidOpen: (NSNotification*)notification
{
	if ([notification object] == theDrawer)
	{
		[theDrawerButton setState: NSOffState];
	}
}

- (void) drawerWillClose: (NSNotification*)notification
{
}

- (void) drawerWillOpen: (NSNotification*)notification
{
}


@end
