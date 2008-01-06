//
//  Source.h
//  Radar
//
//  Created by Daniel Reutter on 5/3/07.
//  Copyright 2007 Technische Universitaet Muenchen. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class User;

@interface Source : NSObject {
	IBOutlet NSView* thePreferencePane;
	NSString* thePreferencePaneTitle;
}

+(NSString*) sourceName;

- (void)SI__loadNibFileNamed:(NSString*) theName;

- (NSView*) preferencePaneView;
- (NSString*) preferencePaneTitle;

/*
 *******************
 * Virtual Methods *
 *******************
*/

/// Main method for scoring users
/** This virtual method takes an NSArray of users and calculates the scores for each user in the array.
  * When done, anObject is informed by sending the aSelector message. The aSelector message takes no argument.
  *
  * This method is virtual! It is implemented by children of the Source class to calculate the different scores.
  */
- (void) scoreUsersInArray: (NSArray*) theUsers
					inform: (id) anObject
				 bySending: (SEL) aSelector;

/// Apply the contents of the preferencePaneView NSView
/** This method should inform the object that it should read and apply the settings made in the preference pane returned
  * by preferencePaneView.
  *
  * This method is virtual! It is implemented by children of the Source class.
  */
- (void) applyPreferencePaneSettings;

/// Initialize the preference pane with the settings
/** This virtual method should init the preference pane NSView returned by preferencePaneView either with
  * default values or with the current preferences, whichever applies.
  *
  * This method is virtual! It is implemented by children of the Source class.
  */
- (void) initPreferencePane;

- (void) savePreferences;
- (void) loadPreferences;

@end
