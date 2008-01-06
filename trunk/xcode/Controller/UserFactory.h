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

/// IBAction Method to be called when an User is added or removed.
/** This method checks the tag of the selected control in a segmented control structure.
  * If it is 1705, addUser is called, if it is 1775 removeUser is called.
  */
- (IBAction) addOrRemoveUserByInterface: (id) sender;

/// IBAction Method to be called when an User is added.
/** This method brings the theAddUserPanel to front, initialized with empty values
  * respectively the default persona image (aka avatar image).
  */
- (IBAction) addUserByInterface: (id) sender;

/// IBAction Method to edit a selected user.
/** This method brings the theAddUserPanel to front, initialized with the values of the
  * first element selected in the theDisplayTable NSTableView.
  * theUserToEdit is set to the selected user.
  */
- (IBAction) editUserByInterface: (id) sender;

/// IBAction Method to delete selected users.
/** This method removes the personae selected in the theDisplayTable NSTableView.
  */
- (IBAction) removeUserByInterface: (id) sender;

/// IBAction Method to add a permanent user to the theUsers NSArray.
/** This method saves the data entered in the theAddUserPanel NSPanel.
  * If the title of theAddUserPanel equals the local translation of the string @"Edit Persona",
  * theUserToEdit's values are overwritten by the field entries. Else a new user is added with
  * the respective values and appended to the theUsers NSArray.
  */
- (IBAction) saveUserFromPanelInput: (id) sender;

/// IBAction Method to open an NSOpenPanel for theAddUserPanel.
/** This method calls an NSOpenPanel for images to select a persona image. openPanelDidEnd: is called
  * after the NSOpenPanel closes.
  */
- (IBAction) openImagePanelForPanel: (id) sender;

/// Method to be called when the NSOpenPanel opened by openImagePanelForPanel: closes.
/** This method sets the respective field in theAddUserPanel with the image whose location is returned by
  * the NSOpenPanel if appropriate. Please see for the NSOpenPanel documentation for further usage.
  */
- (void)openPanelDidEnd:(NSOpenPanel *)panel returnCode:(int)returnCode  contextInfo:(void  *)contextInfo;

/// IBAction Method to import all users from the address book (DEPRECATED)
/** This method imports all users currently in the address book as permanent users into the theUsers array.
  * Since this could lead to a massive overload of permanent users, and it is not necessary anymore to
  * import users from the address book permanently at all, this method is deprecated and should not be used
  * in the future.
  */
- (IBAction) importAllUsersFromAddressBook: (id) sender;

/// IBAction Method to shuffle the persona positions.
/** The persona positions x and y values are initialized with 0. While the y part of the NSPoint value 
  * is determined by the user's score, the x part is determined by random if it is below 0.1. To enforce
  * a new random value, this function provides a mechanism to reset the position value to 0/0.
  */
- (IBAction) shufflePersonaPositions: (id) sender;

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
