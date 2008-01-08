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

/** @File: The preferences are controlled by this class. All permanent data except for the users (controlled by the UserFactory singleton)
  * is controlled by the singleton object of this class.
  */

@interface Preferences : NSObject {
	NSMutableArray* theUsersFromAB;
	
	IBOutlet NSWindow* thePreferencesWindow;
	IBOutlet UserFactory* theUserFactory;
	IBOutlet NSTabView* theTabView;
	IBOutlet NSTabViewItem* theSourceItem;
	
	NSImage* theDefaultImage;
	NSSize maxImageSize;
	BOOL retainImageRatio;
	
	NSTimeInterval theRefreshTime;
	
	BOOL useABDirectly;
	NSArray* theABGroups;
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
	
	unsigned DEBUG__donotwant;
}

/// The child of the abstract Source class currently active
- (Source*) activeSource;

/// NSImage of the defaultAvatarImage
- (NSImage*) defaultAvatarImage;

/// NSTimeInterval representing the cycle time of the score calculation
- (NSTimeInterval) refreshTime;

/// IBAction to open a panel for the selection of an image
/** The image selected via this panel is used as the new defaultAvatarImage.
  */
- (IBAction) openImagePanelForPreferencesWindow: (id) sender;

/// Informal protocol method called by the NSOpenPanel created by openImagePanelForPreferencesWindow:
- (void)openPanelDidEnd:(NSOpenPanel *)panel returnCode:(int)returnCode  contextInfo:(void  *)contextInfo;

/// Load all preferences from the Preferences__mainPlistPath or default them
- (void) loadPreferences;

/// Save all preferences to the Preferences__mainPlistPath
- (void) savePreferences;

/// Save the ABPerson objects selected from the address book
/** Saving is done by saving the UID each AddressBook object possesses
  */
- (NSArray*) saveABUsers;

/// Save the ABGroup selected from the address book
- (NSArray*) saveABGroups;

/// Load the ABPerson objects with the UID in array
- (void) loadABUsersFromArray: (NSArray*) ary;

/// Load the ABGroup objects with the UID in array
- (void) loadABGroupsFromArray: (NSArray*) ary;

/// Apply the preferences set in the thePreferencePane NSPanel
- (IBAction) applyPreferences: (id)sender;

/// Tell the Source NSView to refresh
- (IBAction) refreshSourcePreferencesWindow: (id)sender;

/// Set the preferences in thePreferencePane NSPanel to the current values
- (IBAction) resetPreferencePane: (id)sender;

/// Return the maximal size an image can get
- (NSSize) maxPersonaImageSize;

/// Returns YES if the persona image ratio should be retained
- (BOOL) retainPersonaImageRatio;

/// Called to tidy up
/** The thePreferencePane NSPanel is reset via resetPreferencePane to prevent
  * unwanted behaviour when the NSPanel is closed.
  */
- (void) windowWillClose: (NSNotification*) aNotification;

/// Returns the path to the ApplicationSupport directory for Radar.app
/** Same as calling applicationSupportPathForceExistence: NO
  */
- (NSString*) applicationSupportPath;

/// Returns the path to the ApplicationSupport directory for Radar.app
/** The returned path follows the guidelines of MacOSX programming. A
  * directory is created in ~/Library/Application Support/ in which
  * all items additional to the preferences should be saved, e.g. the
  * permanent users from the UserFactory or theDefaultImage image data.
  */
- (NSString*) applicationSupportPathForceExistence: (BOOL) useForce;

/// Returns an NSArray containing all ABPersons selected from the AddressBook
/** This method also ensures that if only a list of ABGroups is selected, the
  * ABPersons contained therein are returned instead.
  */
- (NSArray*) usersFromAB;

/// Select a new view in theTabView NSTabView
/** Since the source NSViews may be of any size, the selection of the source NSTabViewItem
  * resizes the thePreferencesWindow NSWindow to ensure optimal display size.
  */
- (void)tabView:(NSTabView *)tabView willSelectTabViewItem:(NSTabViewItem *)tabViewItem;

/// Select the source
/** \todo: rename this function
  */
- (IBAction) selectClassFrom: (id) sender;

/// Switch whether the selected ABGroup and ABPerson objects should be used
- (IBAction) switchABUsage: (id) sender;

/// Interpret the selection from the theABPeoplePicker ABPeoplePickerView
- (void) readABUsers;

/// Select the ABPerson and ABGroup objects in theABPeoplePicker ABPeoplePickerView
- (void) selectABUsers;

/// Refresh the display of theABPeoplePicker ABPeoplePickerView
/** This method currently switches the hidden status of the view
  * according to the state of useABDirectly.
  */
- (void) refreshABPeoplePicker;

/// Combo Box INFORMAL Protocol Implementation
- (id)comboBox:(NSComboBox *)aComboBox objectValueForItemAtIndex:(int)index;

/// Combo Box INFORMAL Protocol Implementation
- (int)numberOfItemsInComboBox:(NSComboBox *)aComboBox;

@end
