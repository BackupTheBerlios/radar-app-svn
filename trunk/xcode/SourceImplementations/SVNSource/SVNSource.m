//
//  SVNSource.m
//  Radar
//
//  Created by Daniel Reutter on 19.12.07.
//  Copyright 2007 Techinsche Universitaet Muenchen. All rights reserved.
//

#import "SVNSource.h"


@implementation SVNSource

+ (NSString*) sourceName
{
	NSLog(@"SVN Source Name Requested");
	return(@"Subversion Status");
}

- (id) init
{
	self = [super init];
	if (self != nil)
	{
		[self SI__loadNibFileNamed: @"SVNSourcePrefPane.nib"];
		thePreferencePaneTitle = @"Source: Subversion Status";
//		[self loadPreferences];
	}
	return self;
}

// Source methods.
- (void) scoreUsersInArray: (NSArray*) theUsers
					inform: (id) anObject
				 bySending: (SEL) aSelector
{
	NSLog(@"TODO: SVN SCOREUSERS");
}

- (void) applyPreferencePaneSettings
{
	NSLog(@"TODO: SVN APPLYPREFERENCEPANESETTINGS");
}


- (void) initPreferencePane
{
	NSLog(@"TODO: SVN INITPREFERENCEPANE");
}

- (void) savePreferences
{
	NSLog(@"TODO: SVN SAVEPREFERENCES");
}

- (void) loadPreferences
{
	NSLog(@"TODO: SVN LOADPREFERENCES");
}

@end
