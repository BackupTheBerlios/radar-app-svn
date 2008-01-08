//
//  UserFactory.m
//  Radar
//
//  Created by Daniel Reutter on 5/3/07.
//  Copyright 2007 Technische Universitaet Muenchen. All rights reserved.
//

#import "Defines.h"
#import "UserFactory.h"
#import "AvatarView.h"
#import "Preferences.h"
#import "User.h"
#import "Source.h"
#import "Debug.h"
#import "AddressBook/AddressBook.h"

@implementation UserFactory

- (id) init
{
	self = [super init];
	if (self != nil) {
		theUsers = [[NSMutableArray alloc] initWithCapacity: 10]; // TODO: Save the last value and use it here.
		[[NSNotificationCenter defaultCenter] addObserver: self
												 selector: @selector(applicationWillTerminate:)
													 name: NSApplicationWillTerminateNotification 
												   object: nil];
		
		NSDictionary* infoPList = [[NSBundle mainBundle] infoDictionary];
		UserFactory__plistFileName = [infoPList valueForKey: @"UserPropertyList"];
	}
	return self;
}

- (void) awakeFromNib
{
	[theInfoView setFieldEditor: YES];
	[self loadUsers: self];
	[self refreshUsers: self];
}

- (IBAction) refreshUsers: (id)sender
{
	[theUsers removeObjectsInArray: [self usersFromAddressBook]];
	[self importABUsersFromArray: [thePreferences usersFromAB]
					 permanently: NO];
	[self calculateUserScores];
	[self calculateUserScoresEvery: [thePreferences refreshTime]];
}

- (BOOL) addUser: (User*) newUser
{
	[theUsers addObject: [newUser retain]];
	[self hasChanged];
	
	return TRUE;
}

- (BOOL) addNewUserWithName: (NSString*)aName withInfo: (NSString*)anInfo withImage: (NSImage*)anImage
{
	User* newUser = [[User alloc] initWithName:aName withInfo:anInfo withImage:anImage withSource:@"Direct"];
	return [self addUser: newUser];
}

- (void) hasChanged
{
	[theUserTable noteNumberOfRowsChanged];
	[theUserTable reloadData];
	[theDisplayTable noteNumberOfRowsChanged];
	[theDisplayTable reloadData];
	[theAvatarView setNeedsDisplay: YES];
}

- (BOOL) addNewUserFromABPerson: (ABPerson*) anABPerson
{
	return [self addNewUserFromABPerson: (ABPerson*) anABPerson 
							permanently: YES];
}

- (BOOL) addNewUserFromABPerson: (ABPerson*) anABPerson permanently: (BOOL) permanently
{
	NSString* firstName = [anABPerson valueForProperty: kABFirstNameProperty];
	NSString* lastName = [anABPerson valueForProperty: kABLastNameProperty];

	if (firstName == nil && lastName == nil)
	{
		// all is nil, no name - no person. Sorry.
		return FALSE;
	}
	firstName = firstName?firstName:@"";
	lastName = lastName?lastName:@"";
	
	NSString* theName = [[firstName stringByAppendingString: @" "] stringByAppendingString: lastName];
	
	NSImage* image;
	
	if ([anABPerson imageData] == nil)
	{
		image = [thePreferences defaultAvatarImage];
	}
	else
	{
		image = [[NSImage alloc] initWithData: [anABPerson imageData]];
	}
	
	NSString* infoString = [anABPerson valueForProperty: kABNoteProperty];
	
	infoString = infoString?infoString:@"";
	
	User* theNewUser = [[User alloc] initWithName: theName
										 withInfo: infoString
										withImage: image
									   withSource: permanently?@"Address Book":anABPerson];
	
	
	return [self addUser: theNewUser];
}

- (NSArray*) allUsers
{
	return theUsers;
}

- (IBAction) importAllUsersFromAddressBook: (id) sender
{
	[self importABUsersFromArray: [[ABAddressBook sharedAddressBook] people] permanently: YES];
}

- (void) importABUsersFromArray: (NSArray*) people permanently: (BOOL) permanently
{
	unsigned i;
	
	for (i = 0; i < [people count]; ++i)
	{
		ABRecord* rec = [people objectAtIndex: i];
		if ([rec isKindOfClass: [ABPerson class]])
		{
			[self addNewUserFromABPerson: (ABPerson*)rec permanently: permanently];
		}
		else if ([rec isKindOfClass: [ABGroup class]])
		{
			[self importABUsersFromArray: [(ABGroup*)rec members] permanently: permanently];
		}
	}	
}

- (IBAction) addOrRemoveUserByInterface: (id) sender
{
	int clickedSegment = [sender selectedSegment];
	int clickedSegmentTag = [[sender cell] tagForSegment:clickedSegment];
	
	if (clickedSegmentTag == SEGMENT_NEW_USER_TAG)
	{
		[self addUserByInterface: sender];
	}
	if (clickedSegmentTag == SEGMENT_REMOVE_USER_TAG)
	{
		[self removeUserByInterface: sender];
	}
	if (clickedSegmentTag == SEGMENT_EDIT_USER_TAG)
	{
		[self editUserByInterface: sender];
	}
}

- (IBAction) addUserByInterface: (id) sender
{
	if (![theAddUserPanel isVisible])
	{
		[theAddUserPanel setTitle: NSLocalizedString(@"Add Persona", @"AddUserPanel Title")];
		[theNameField setStringValue: @""];
		[theInfoView setString: @""];
		[theUserImage setImage: [thePreferences defaultAvatarImage]];
		[theAddUserPanel makeFirstResponder: theNameField];
	}
	[theAddUserPanel makeKeyAndOrderFront: self];
}

- (IBAction) editUserByInterface: (id) sender
{
	if (![theAddUserPanel isVisible])
	{
		theUserToEdit = [[self permanentUsers] objectAtIndex: [[theUserTable selectedRowIndexes] firstIndex]];
		[theAddUserPanel setTitle: NSLocalizedString(@"Edit Persona", @"EditUserPanel Title")];
		[theNameField setStringValue: [theUserToEdit valueForKey: @"theName"]];
		[theInfoView setString: [[theUserToEdit valueForKey: @"theInfo"] copy]];
		[theUserImage setImage: [theUserToEdit valueForKey: @"theImage"]];
		[theAddUserPanel makeFirstResponder: theNameField];
	}
	[theAddUserPanel makeKeyAndOrderFront: self];
}

- (IBAction) removeUserByInterface: (id) sender
{
	NSArray* theUsersToRemove = [[self permanentUsers] objectsAtIndexes: [theUserTable selectedRowIndexes]];
	[theUsers removeObjectsInArray: theUsersToRemove];
	[self hasChanged];
}

- (void) removeUserWithIndex: (unsigned) index
{
	[theUsers removeObjectAtIndex: index];
	[theUserTable deselectAll: self];
	[self hasChanged];
}

- (IBAction) saveUserFromPanelInput: (id) sender
{
	if ([[theAddUserPanel title] localizedCompare: @"Edit Persona"] == NSOrderedSame)
	{
		[theUserToEdit setValue: [theNameField stringValue] forKey: @"theName"];
		[theUserToEdit setValue: [[theInfoView string] copy] forKey: @"theInfo"];
		[theUserToEdit setValue: [theUserImage image] forKey: @"theImage"];
	}
	else
	{
		[theAddUserPanel setTitle: NSLocalizedString(@"Edit Persona", @"EditUserPanel Title")];
		User* theNewUser = [[User alloc] initWithName: [theNameField stringValue]
											 withInfo: [theInfoView string]
											withImage: [theUserImage image] 
										   withSource: @"User Interface"];
			
		[self addUser: theNewUser];
		theUserToEdit = theNewUser;
	}

	[self hasChanged];
	
	if ([sender tag] != BUTTON_ADD_USER_APPLY_TAG)
	{
		[theAddUserPanel close];
	}

}

- (IBAction) openImagePanelForPanel: (id) sender
{
	NSOpenPanel* thePanel = [NSOpenPanel openPanel];
	[thePanel setAllowedFileTypes: [NSImage imageFileTypes]];
	[thePanel setAllowsMultipleSelection: NO];
	[thePanel beginSheetForDirectory: nil
								file: nil
					  modalForWindow: theAddUserPanel 
					   modalDelegate: self
					  didEndSelector: @selector(openPanelDidEnd:returnCode:contextInfo:)
						 contextInfo: @"ImageFileSelectPanel"];
}

- (IBAction) shufflePersonaPositions: (id) sender
{
	NSPoint newPos;
	newPos.x = 0.0;
	newPos.y = 0.0;
	int i;
	for (i = 0; i < [theUsers count]; ++i)
	{
		[[theUsers objectAtIndex: i] setLastPosition: newPos];
	}
	[self hasChanged];
}

- (void)openPanelDidEnd:(NSOpenPanel *)panel returnCode:(int)returnCode  contextInfo:(void  *)contextInfo
{
	if (returnCode == NSCancelButton)
	{
		return;
	}
	
	[theUserImage setImage: [[NSImage alloc] initWithContentsOfFile: [[panel filenames] lastObject]]];
}

- (NSArray*) permanentUsers
{
	DSetContext(@"permanentUsers");
	unsigned i;
	NSMutableArray* retAry = [NSMutableArray arrayWithCapacity: [theUsers count]];
	for (i = 0; i < [theUsers count]; ++i)
	{
		if ([[[theUsers objectAtIndex: i] valueForKey: @"theSource"] isKindOfClass: [NSString class]])
		{
			[retAry addObject: [theUsers objectAtIndex: i]];
		}
	}
	
	DLog(@"Got the FOLLOWING: %@", retAry);
	return [NSArray arrayWithArray: retAry];
}

- (NSArray*) usersFromAddressBook
{
	DSetContext(@"ABUsers");
	unsigned i;
	NSMutableArray* retAry = [NSMutableArray arrayWithCapacity: [theUsers count]];
	for (i = 0; i < [theUsers count]; ++i)
	{
		if ([[[theUsers objectAtIndex: i] valueForKey: @"theSource"] isKindOfClass: [ABPerson class]])
		{
			[retAry addObject: [theUsers objectAtIndex: i]];
		}
	}
	
	DLog(@"Got the FOLLOWING: %@", retAry);
	return [NSArray arrayWithArray: retAry];
}

// Table View Data Handling

- (int)numberOfRowsInTableView:(NSTableView *)aTableView
{
	if ([aTableView tag] == COMPLETE_USER_TABLEVIEW)
	{
		return [theUsers count];
	}
	if ([aTableView tag] == PERMANENT_USER_TABLEVIEW)
	{
		return [[self permanentUsers] count];
	}
	return 0;
}

- (id)tableView:(NSTableView *)aTableView
    objectValueForTableColumn:(NSTableColumn *)aTableColumn
    row:(int)rowIndex
{
	
	User* requestedUser;
	if ([aTableView tag] == COMPLETE_USER_TABLEVIEW)
	{
		requestedUser = [theUsers objectAtIndex: rowIndex];
	}
	else
	{
		requestedUser = [[self permanentUsers] objectAtIndex: rowIndex];
	}
	id col_id = [aTableColumn identifier];
	if ([@"ImageColumn" compare: col_id] == NSOrderedSame)
	{
		return [requestedUser valueForKey: @"theImage"];
	}
	else
	{
		//[[aTableColumn cell] ];
/*		NSDictionary* infoFormat = [NSDictionary dictionaryWithObjects: [NSArray arrayWithObjects: [NSFont systemFontOfSize: [NSFont smallSystemFontSize]], [NSColor grayColor], nil]
															   forKeys: [NSArray arrayWithObjects: NSFontAttributeName, NSForegroundColorAttributeName, nil]];
		NSMutableAttributedString* returnString = [[NSMutableAttributedString alloc] initWithString: [requestedUser valueForKey: @"theName"]];
		[returnString appendAttributedString: [[NSAttributedString alloc] initWithString: @"\n"]];
		[returnString appendAttributedString: [[NSAttributedString alloc]	initWithString: [requestedUser valueForKey: @"theInfo"] 
																			attributes: infoFormat]];*/
		return [NSString stringWithFormat: @"%@\n(%@)", [requestedUser valueForKey: @"theName"], [requestedUser valueForKey: @"theInfo"]];
	}
}

- (void)tableViewSelectionDidChange:(NSNotification *)aNotification
{
	[self updateControls];
}

- (void)updateControls
{
	if ([theUserTable numberOfSelectedRows] == 0)
	{
		[theControls setEnabled: NO forSegment: 1];
		[theControls setEnabled: NO forSegment: 2];
	}
	else
	{
		[theControls setEnabled: YES forSegment: 1];
		[theControls setEnabled: YES forSegment: 2];
	}
}

- (void) calculateUserScores
{
	NSArray* allTheUsers = [self allUsers];
	
	[[thePreferences activeSource] scoreUsersInArray: allTheUsers
											  inform: self
										   bySending: @selector(reorderUsers)];
}

- (void) reorderUsers
{
	[theUsers sortUsingSelector: @selector(compareWith:)];
	[self hasChanged];
}

- (void) calculateUserScoresEvery: (NSTimeInterval) theInterval
{
	if (theCalculateUserTimer != nil)
	{
		[theCalculateUserTimer invalidate];
	}
	theCalculateUserTimer = [NSTimer scheduledTimerWithTimeInterval: theInterval 
												target: self 
											  selector: @selector(calculateUserScoresTimer:)
											  userInfo: nil
											   repeats: YES];
}

- (void) calculateUserScoresTimer: (NSTimer*) theTimer
{
	[self calculateUserScores];
}

- (IBAction) loadUsers: (id)sender
{
	NSArray* userPList = [NSKeyedUnarchiver unarchiveObjectWithFile: [[thePreferences applicationSupportPath] stringByAppendingPathComponent: UserFactory__plistFileName]];
	
	if (userPList == nil)
	{
		return;
	}
		
	unsigned i;
	for (i = 0; i < [userPList count]; ++i)
	{
		User* newUser = [User alloc];
		[newUser initWithDictionary: [userPList objectAtIndex: i]];
		[theUsers addObject: [newUser retain]];
	}
	
	[self hasChanged];
}

- (IBAction) saveUsers: (id)sender
{
	NSMutableArray* userPList = [[NSMutableArray alloc] init];
	
	NSArray* saveUsers = [self permanentUsers];
	unsigned i;
	for (i = 0; i < [saveUsers count]; ++i)
	{
		User* actualUser = [saveUsers objectAtIndex: i];

		[userPList addObject: [[actualUser dictionary] retain]];
	}
	
	if (![NSKeyedArchiver archiveRootObject: userPList 
									 toFile: [[thePreferences applicationSupportPathForceExistence: YES] stringByAppendingPathComponent: UserFactory__plistFileName]])
	{
		NSLog(@"Saving personae failed."); // KEEP THIS LOG
	}
}

- (void) applicationWillTerminate: (NSNotification*) aNotification
{
	[self saveUsers: self];
}


@end
