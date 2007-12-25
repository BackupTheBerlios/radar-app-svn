//
//  Source.m
//  Radar
//
//  Created by Daniel Reutter on 5/3/07.
//  Copyright 2007 Technische Universitaet Muenchen. All rights reserved.
//

#import "Source.h"
#import "User.h"
#import "UserFactory.h"
#import "Defines.h"

#import "Debug.h"

@implementation Source

+ (NSString*) sourceName
{
	[NSException raise: VirtualMethodException format: @"Called sourceName as a virtual method of Source."];
	return nil;
}

- (id) init
{
	DSetContext(@"Source init");
	self = [super init];
	if (self != nil)
	{
		DLog(@"Source initialized");
	}
	return self;
}

- (void)SI__loadNibFileNamed:(NSString*) theName
{
	DSetContext(@"Source Internal Function: loadNibFileNamed");
    NSNib* aNib = [[NSNib alloc] initWithNibNamed:theName bundle:nil];
	
    if (![aNib instantiateNibWithOwner:self topLevelObjects:nil])
    {
        NSLog(@"Warning! Could not load nib file.\n"); // KEEP THIS LOG
        return;
    }
    // Release the raw nib data.
	
	DLog(@"Nib loaded.");
	
    [aNib release];
 }

- (void) scoreUsersInArray: (NSArray*) theUsers
					inform: (id) anObject
				 bySending: (SEL) aSelector
{
	[NSException raise: VirtualMethodException format: @"Called getScoreForUser: as a virtual method of Source."];
}

- (NSView*) preferencePaneView
{
	return thePreferencePane;
}

- (NSString*) preferencePaneTitle
{
	NSLog(@"Returning %@... hoo", thePreferencePaneTitle);
	return thePreferencePaneTitle;
}
- (void) applyPreferencePaneSettings
{
	[NSException raise: VirtualMethodException format: @"Called applyPreferencePaneSettings as a virtual method of Source."];	
}

- (void) initPreferencePane
{
	[NSException raise: VirtualMethodException format: @"Called initPreferencePane as a virtual method of Source."];	
}

- (void) savePreferences
{
	[NSException raise: VirtualMethodException format: @"Called savePreferences as a virtual method of Source."];
}

- (void) loadPreferences
{
	[NSException raise: VirtualMethodException format: @"Called loadPreferences as a virtual method of Source."];
}

@end
