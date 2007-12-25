//
//  UserFactory.h
//  Radar
//
//  Created by Daniel Reutter on 5/3/07.
//  Copyright 2007 Technische Universitaet Muenchen. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <AddressBook/AddressBook.h>

@class User;
@class AvatarView;
@class Preferences;

@interface UserFactory : NSObject
{
	NSMutableArray* theUsers;
	
	// Add Persona Panel outlets
	IBOutlet NSPanel* theAddUserPanel;
	IBOutlet NSTextField* theNameField;
	IBOutlet NSTextView* theInfoView;
	IBOutlet NSImageView* theUserImage;
	
	// Displays of the Users
	IBOutlet NSTableView* theUserTable;
	IBOutlet NSTableView* theDisplayTable;
	IBOutlet NSSegmentedControl* theControls;
	
	IBOutlet AvatarView* theAvatarView;
	
	IBOutlet Preferences* thePreferences;
	
	User* theUserToEdit;
	
	NSTimer* theCalculateUserTimer;
	
	@private NSString* UserFactory__plistFileName;
}

- (IBAction) loadUsers: (id)sender;
- (IBAction) saveUsers: (id)sender;
- (IBAction) refreshUsers: (id)sender;
- (void) applicationWillTerminate: (NSNotification*) aNotification;

- (BOOL) addUser: (User*) newUser;
- (BOOL) addNewUserWithName: (NSString*)aName withInfo: (NSString*)anInfo withImage: (NSImage*)anImage;
- (NSArray*) allUsers;

- (void) hasChanged;
- (void) reorderUsers;
- (void) updateControls;
- (void) calculateUserScores;

- (void) importABUsersFromArray: (NSArray*) people permanently: (BOOL) permanently;
- (BOOL) addNewUserFromABPerson: (ABPerson*) anABPerson;
- (BOOL) addNewUserFromABPerson: (ABPerson*) anABPerson permanently: (BOOL) permanently;

- (NSArray*) permanentUsers;
- (NSArray*) usersFromAddressBook;

/// Method to be called when an User is added or removed.
/** This method checks the tag of the selected control in a segmented control structure.
  * If it is 1705, addUser is called, if it is 1775 removeUser is called.
  */
- (IBAction) addOrRemoveUserByInterface: (id) sender;

- (IBAction) addUserByInterface: (id) sender;

- (IBAction) editUserByInterface: (id) sender;

- (IBAction) removeUserByInterface: (id) sender;

- (IBAction) saveUserFromPanelInput: (id) sender;

- (IBAction) openImagePanelForPanel: (id) sender;
- (void)openPanelDidEnd:(NSOpenPanel *)panel returnCode:(int)returnCode  contextInfo:(void  *)contextInfo;

- (IBAction) importAllUsersFromAddressBook: (id) sender;

/// Methods for Table Data
- (id)tableView:(NSTableView *)aTableView
    objectValueForTableColumn:(NSTableColumn *)aTableColumn
    row:(int)rowIndex;

- (int)numberOfRowsInTableView:(NSTableView *)aTableView;

- (void)tableViewSelectionDidChange:(NSNotification *)aNotification;

/// Timer method to be set for the timer
- (void) calculateUserScoresTimer: (NSTimer*) theTimer;

- (void) calculateUserScoresEvery: (NSTimeInterval) theInterval;

@end
