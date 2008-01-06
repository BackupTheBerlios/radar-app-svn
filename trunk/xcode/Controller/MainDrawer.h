//
//  MainDrawer.h
//  Radar
//
//  Created by Daniel Reutter on 30.05.07.
//  Copyright 2007 Technische Universitaet Muenchen. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "UserFactory.h"

/** @File: The MainDrawer class controls the drawer of the main window.
  */
@interface MainDrawer : NSObject {
// Drawer settings
	IBOutlet NSButton* theDrawerButton;
	IBOutlet NSDrawer* theDrawer;
	
// Data Source
	IBOutlet UserFactory* theUserFactory;
}

// Delegate Methods for the Drawer Handling
- (void) drawerDidClose: (NSNotification*)notification;
- (void) drawerDidOpen: (NSNotification*)notification;
- (void) drawerWillClose: (NSNotification*)notification;
- (void) drawerWillOpen: (NSNotification*)notification;

@end
