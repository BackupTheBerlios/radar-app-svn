//
//  Windows.h
//  Radar
//
//  Created by Daniel Reutter on 5/8/07.
//  Copyright 2007 Technische Universitaet Muenchen. All rights reserved.
//

#import <Cocoa/Cocoa.h>

/** @File: This class controls all main windows of the application.
  * It has only full control over the about panel.
  */

@interface Windows : NSObject {
	IBOutlet NSWindow* theMainWindow;
	IBOutlet NSWindow* thePreferencesWindow;
	IBOutlet NSWindow* thePersonaeManagerWindow;

// About-Panel settings
	IBOutlet NSPanel* theAboutPanel;
	IBOutlet NSTextField* theAppNameText;
	IBOutlet NSTextField* theVersionText;
	IBOutlet NSTextField* theCopyrightText;
	IBOutlet NSTextField* theProgrammerText;
	}

/// IBAction to activate the main window.
- (IBAction) activateTheMainWindow: (id) sender;

/// IBAction to activate the preferences window.
- (IBAction) activateThePreferencesWindow: (id) sender;

/// IBAction to activate the about panel.
- (IBAction) activateTheAboutPanel: (id) sender;

@end
