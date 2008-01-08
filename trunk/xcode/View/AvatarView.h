//
//  AvatarView.h
//  Radar
//
//  Created by Daniel Reutter on 5/17/07.
//  Copyright 2007 Technische Universitaet Muenchen. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class UserFactory;
@class Preferences;

@interface AvatarView : NSView
{
	/// The UserFactory containing all users that are to be displayed
	IBOutlet UserFactory* theUserFactory;
	IBOutlet Preferences* thePreferences;
}

@end
