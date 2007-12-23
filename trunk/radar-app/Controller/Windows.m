//
//  Windows.m
//  Radar
//
//  Created by Daniel Reutter on 5/8/07.
//  Copyright 2007 Technische Universitaet Muenchen. All rights reserved.
//

#import "Windows.h"


@implementation Windows

- (id) init {
	self = [super init];
	if (self != nil) {
	}
	return self;
}

- (IBAction) activateTheMainWindow: (id) sender
{
	[theMainWindow makeKeyAndOrderFront: self];
}

- (IBAction) activateThePreferencesWindow: (id) sender
{
	[thePreferencesWindow makeKeyAndOrderFront: self];
}

- (IBAction) activateTheAboutPanel: (id) sender
{
	NSDictionary* infoPlist = [[NSBundle mainBundle] infoDictionary];
	NSDictionary* localPlist = [[NSBundle mainBundle] localizedInfoDictionary];
	
	[theAboutPanel makeKeyAndOrderFront: self];
	
	[theAppNameText setStringValue: [infoPlist valueForKey:@"CFBundleExecutable"]];
	[theVersionText setStringValue: [infoPlist valueForKey:@"CFBundleVersion"]];
	[theCopyrightText setStringValue: [localPlist valueForKey:@"NSHumanReadableCopyright"]];
	[theProgrammerText setStringValue: [localPlist valueForKey:@"NSHumanReadableDevelopers"]];
	
}

@end
