//
//  Preferences.h
//  Radar
//
//  Created by Daniel Reutter on 23.06.07.
//  Copyright 2007 Technische Universitaet Muenchen. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <AddressBook/AddressBook.h>
#import <AddressBook/AddressBookUI.h>

@class UserFactory;
@class Source;

@interface Preferences : NSObject {
	NSMutableArray* theUsersFromAB;
	
	IBOutlet NSWindow* thePreferencesWindow;
	IBOutlet UserFactory* theUserFactory;
	IBOutlet NSTabView* theTabView;
	IBOutlet NSTabViewItem* theSourceItem;
	
	NSImage* theDefaultImage;
	NSTimeInterval theRefreshTime;
	
	BOOL useABDirectly;
	BOOL groupsFromABSelected;
	NSArray* theABUsers;
	
	Source* theActiveSource;
	NSString* selectedSource;
	
	IBOutlet NSTextField* theRefreshTimeField;
	IBOutlet NSComboBox* theSourceSelection;
	IBOutlet NSImageView* theDefaultAvatarImageView;
	IBOutlet NSButton* theABUsageActivationButton;
	IBOutlet ABPeoplePickerView* theABPeoplePicker;
	
	@private NSString* Preferences__mainPlistPath;
	@private NSSize Preferences__sourcePrefWindowSize;
	@private NSSize Preferences__originalPrefWindowSize;
	
	NSDictionary* theSources;
}

- (Source*) activeSource;

- (NSImage*) defaultAvatarImage;
- (NSTimeInterval) refreshTime;

- (IBAction) openImagePanelForPreferencesWindow: (id) sender;
- (void)openPanelDidEnd:(NSOpenPanel *)panel returnCode:(int)returnCode  contextInfo:(void  *)contextInfo;

- (void) loadPreferences;
- (void) savePreferences;
- (NSArray*) saveABUsers;
- (void) loadABUsersFromArray: (NSArray*) ary;

- (IBAction) applyPreferences: (id)sender;
- (IBAction) refreshSourcePreferencesWindow: (id)sender;

- (IBAction) resetPreferencePane: (id)sender;

- (void) windowWillClose: (NSNotification*) aNotification;
- (void) windowDidBecomeKey: (NSNotification*) aNotification;

- (NSString*) applicationSupportPath;
- (NSString*) applicationSupportPathForceExistence: (BOOL) useForce;

- (NSArray*) usersFromAB;

// Delegate
- (void)tabView:(NSTabView *)tabView willSelectTabViewItem:(NSTabViewItem *)tabViewItem;

- (IBAction) selectClassFrom: (id) sender;

- (IBAction) switchABUsage: (id) sender;
- (void) readABUsers;
- (void) refreshABPeoplePicker;

// Combo Box INFORMAL Protocol Implementation
- (id)comboBox:(NSComboBox *)aComboBox objectValueForItemAtIndex:(int)index;
- (int)numberOfItemsInComboBox:(NSComboBox *)aComboBox;

- (void) DEBUG__blubbWithPeople: (NSArray*) people;
- (IBAction) DEBUG__testAB: (id) sender;

@end
