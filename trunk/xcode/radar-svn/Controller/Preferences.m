//
//  Preferences.m
//  Radar
//
//  Created by Daniel Reutter on 23.06.07.
//  Copyright 2007 Technische Universitaet Muenchen. All rights reserved.
//

#import "Preferences.h"
#import "UserFactory.h"

#import "Sources.h"

#import "Debug.h"

@implementation Preferences
- (id) init
{
	DSetContext(@"Preferences init");
	self = [super init];
	if (self != nil) 
	{
		NSDictionary* infoPlist = [[NSBundle mainBundle] infoDictionary];
		
		Preferences__mainPlistPath =  [[[NSString stringWithFormat: @"~/Library/Preferences/%@.%@", 
			[infoPlist valueForKey: @"CFBundleIdentifier"],
			[infoPlist valueForKey: @"MainPropertyListIdentifier"]] stringByExpandingTildeInPath] retain];
		
		// Sources list generation
		theSources = [[Sources sources] retain];
		
		[self loadPreferences];
		DLog(@"Initialized self");
	}
	return self;
}

- (void) awakeFromNib
{
	Preferences__originalPrefWindowSize = [thePreferencesWindow frame].size;
	[self resetPreferencePane: self];
}

- (Source*) activeSource
{
	return theActiveSource;
}

- (NSString*) applicationSupportPath
{
	return [self applicationSupportPathForceExistence: NO];
}

- (NSString*) applicationSupportPathForceExistence: (BOOL) useForce
{
	DSetContext(@"Preferences: applicationSupportPath");
	NSString* applicationSupportPath = [@"~/Library/Application Support/Radar" stringByExpandingTildeInPath]; // TODO: read this from plist
	
	DLog(@"applicationSupportPath is %@", applicationSupportPath);
	
	if (useForce)
	{
		BOOL isDir;
		NSFileManager* fileMan = [NSFileManager defaultManager];
		
		if(![fileMan fileExistsAtPath: applicationSupportPath isDirectory: &(isDir)])
		{
			NSLog(@"Attempting to create directory '%@'.", applicationSupportPath); // KEEP THIS LOG
			if (![fileMan createDirectoryAtPath: applicationSupportPath attributes: nil])
			{
				NSLog(@"Attempt failed."); // KEEP THIS LOG
				DLog(@"Failure!");
				return nil;
			}
		}
		else
		{
			if (!isDir)
			{
				NSLog(@"%@ is no directory.", applicationSupportPath); // KEEP THIS LOG
				DLog(@"Failure!");
				return nil;
			}
		}
	}
	DLog(@"Success. Returning %@", applicationSupportPath);
	return applicationSupportPath;

}

- (IBAction) resetPreferencePane: (id)sender
{
	DSetContext(@"resetPreferencePane");
	[theDefaultAvatarImageView setImage: theDefaultImage];
	[theRefreshTimeField setIntValue: theRefreshTime];
	[theRefreshTimeField sendAction: [theRefreshTimeField action] to: [theRefreshTimeField target]];
	
	[self refreshSourcePreferencesWindow: self];
	
	[theTabView selectFirstTabViewItem: self];
	[thePreferencesWindow makeFirstResponder: [thePreferencesWindow initialFirstResponder]];
	
	[theSourceSelection setStringValue: [[theSources allKeysForObject: [theActiveSource class]] objectAtIndex: 0]];
	
	if (useABDirectly)
	{
		[theABUsageActivationButton setState: NSOnState];
	}
	else
	{
		[theABUsageActivationButton setState: NSOffState];
	}
	
	[theABPeoplePicker deselectAll: self];
	DLog(@"Got Array: %@", theABUsers);
	unsigned i;
	if (theABUsers)
	{
		for (i = 0; i < [theABUsers count]; ++i)
		{
			if (groupsFromABSelected)
			{
				[theABPeoplePicker selectGroup: [theABUsers objectAtIndex: i]
						  byExtendingSelection: i];
			}
			else
			{
				[theABPeoplePicker selectRecord: [theABUsers objectAtIndex: i]
						   byExtendingSelection: i];
			}
		}
	}
	
	NSLog(@"4");
	[self refreshABPeoplePicker];
	NSLog(@"5");
}

- (void) windowDidBecomeKey: (NSNotification*) aNotification
{
}

- (void) windowWillClose: (NSNotification*) aNotification
{
	[self resetPreferencePane: self];
}

- (NSImage*) defaultAvatarImage
{
	return theDefaultImage;
}

- (NSTimeInterval) refreshTime
{
	return theRefreshTime;
}

- (void) loadPreferences
{
	NSDictionary* currentSettings = [NSDictionary dictionaryWithContentsOfFile: Preferences__mainPlistPath];
	
	theRefreshTime = [[currentSettings valueForKey: @"RefreshTime"] floatValue];
	if (theRefreshTime < 0.01)
	{
		theRefreshTime = 10.0;
	}

	theDefaultImage = [[NSImage alloc] initWithContentsOfFile: [[self applicationSupportPath] stringByAppendingPathComponent: @"default.png"]];
	
	if (theDefaultImage == nil)
	{
		[theDefaultImage release];
		theDefaultImage = [[NSImage alloc] initWithContentsOfFile: [[NSBundle mainBundle] pathForImageResource: @"Default.png"]];
	}
	
	selectedSource = [currentSettings valueForKey: @"ActiveSource"];
	selectedSource = selectedSource?selectedSource:@"Mail Source";
	
	theActiveSource = [[[theSources objectForKey: selectedSource] alloc] init];
	
	useABDirectly = [[currentSettings valueForKey: @"UseABDirectly"] boolValue];
	groupsFromABSelected = [[currentSettings valueForKey: @"ABGroupsSelected"] boolValue];
	
	NSArray* ary = [currentSettings valueForKey: @"ABUsers"];
	if (ary)
	{
		[self loadABUsersFromArray: ary];
	}
	else
	{
		theABUsers = NULL;
	}
}

- (void) savePreferences
{
	NSMutableDictionary* currentSettings = [NSMutableDictionary dictionaryWithContentsOfFile: Preferences__mainPlistPath];
	
	if (currentSettings == nil)
	{
		currentSettings = [NSMutableDictionary dictionaryWithCapacity: 1];
	}
		
	[currentSettings setValue: [NSString stringWithFormat: @"%.2f", theRefreshTime] forKey: @"RefreshTime"];
	[currentSettings setValue: selectedSource forKey: @"ActiveSource"];
	
	[currentSettings setValue: useABDirectly?@"YES":@"NO" forKey: @"UseABDirectly"];
	[currentSettings setValue: groupsFromABSelected?@"YES":@"NO" forKey: @"ABGroupsSelected"];
	
	[currentSettings setValue: [self saveABUsers] forKey: @"ABUsers"];
	
	NSData* defaultPictureFile = [[NSBitmapImageRep imageRepWithData: [theDefaultImage TIFFRepresentation]] representationUsingType: NSPNGFileType properties: nil];
	
	[defaultPictureFile writeToFile: [[self applicationSupportPathForceExistence: YES] stringByAppendingPathComponent: @"default.png"] atomically: YES];
	
	if (![currentSettings writeToFile: Preferences__mainPlistPath
						   atomically: YES])
	{
		NSLog(@"Error writing preferences to %@.", Preferences__mainPlistPath); // KEEP THIS LOG
	}
	
	[theActiveSource savePreferences];
}

- (NSArray*) saveABUsers
{
	if (!theABUsers)
	{
		return NULL;
	}
	
	NSMutableArray* IDs = [NSMutableArray arrayWithCapacity: [theABUsers count]];
	
	unsigned i;
	for (i = 0; i < [theABUsers count]; ++i)
	{
		[IDs addObject: [(ABRecord*)[theABUsers objectAtIndex: i] uniqueId]];
	}
	
	return [NSArray arrayWithArray: IDs];
}

- (void) loadABUsersFromArray: (NSArray*) ary
{
	if (theABUsers)
	{
		[theABUsers release];
		theABUsers = NULL;
	}
	
	NSLog(@"Here...");
	NSMutableArray* newABUsers = [NSMutableArray arrayWithCapacity: [ary count]];
	unsigned i;
	for (i = 0; i < [ary count]; ++i)
	{
		ABRecord* newRecord = [[ABAddressBook sharedAddressBook] recordForUniqueId: [ary objectAtIndex: i]];
		if (newRecord)
		{
			[newABUsers addObject: newRecord];
		}
	}
	
	theABUsers = [NSArray arrayWithArray: newABUsers];
	[theABUsers retain];
}

- (IBAction) applyPreferences: (id)sender
{
	[theActiveSource applyPreferencePaneSettings];
	
	theDefaultImage = [theDefaultAvatarImageView image];
	theRefreshTime = [theRefreshTimeField floatValue];
	selectedSource = [theSourceSelection stringValue];
	
	[self readABUsers];
	
	[theUserFactory calculateUserScoresEvery: theRefreshTime];	
	[theUserFactory calculateUserScores];
	
	[self savePreferences];
	[thePreferencesWindow close];
}

- (void) readABUsers
{
	if (theABUsers)
	{
		[theABUsers release];
		theABUsers = NULL;
	}
	
	NSArray* recs = [theABPeoplePicker selectedRecords];
	if ([recs count] == 0)
	{
		groupsFromABSelected = YES;
		recs = [theABPeoplePicker selectedGroups];
	}
	
	theABUsers = [NSArray arrayWithArray: recs];
	[theABUsers retain];
}

- (IBAction) refreshSourcePreferencesWindow: (id)sender
{
	[theSourceItem setView: [theActiveSource preferencePaneView]];
	[theActiveSource initPreferencePane];
	[theSourceItem setLabel: [theActiveSource preferencePaneTitle]];
	
	NSRect prefWindowRect = [thePreferencesWindow frame];
	NSRect interiorViewRect = [[[theTabView tabViewItemAtIndex: 0] view] frame];
	
	Preferences__sourcePrefWindowSize.width = [[theActiveSource preferencePaneView] frame].size.width + (prefWindowRect.size.width - interiorViewRect.size.width);
	Preferences__sourcePrefWindowSize.height = [[theActiveSource preferencePaneView] frame].size.height + (prefWindowRect.size.height - interiorViewRect.size.height);
}

- (IBAction) openImagePanelForPreferencesWindow: (id) sender
{
	NSOpenPanel* thePanel = [NSOpenPanel openPanel];
	[thePanel setAllowedFileTypes: [NSImage imageFileTypes]];
	[thePanel setAllowsMultipleSelection: NO];
	[thePanel beginSheetForDirectory: nil
								file: nil
					  modalForWindow: thePreferencesWindow 
					   modalDelegate: self
					  didEndSelector: @selector(openPanelDidEnd:returnCode:contextInfo:)
						 contextInfo: @"ImageFileSelectPanel"];
}

- (void)openPanelDidEnd:(NSOpenPanel *)panel returnCode:(int)returnCode  contextInfo:(void  *)contextInfo
{
	if (returnCode == NSCancelButton)
	{
		return;
	}
	
	[theDefaultAvatarImageView setImage: [[NSImage alloc] initWithContentsOfFile: [[panel filenames] lastObject]]];
}

- (void)tabView:(NSTabView *)tabView willSelectTabViewItem:(NSTabViewItem *)tabViewItem
{
	
	NSRect newFrame = [thePreferencesWindow frame];
	float deltaY = newFrame.size.height;
	
	if ([tabViewItem view] == [theActiveSource preferencePaneView])
	{
		newFrame.size = Preferences__sourcePrefWindowSize;
	}
	else
	{
		newFrame.size = Preferences__originalPrefWindowSize;
	}
	
	deltaY -= newFrame.size.height;
	newFrame.origin.y += deltaY;
	
	[thePreferencesWindow setFrame: newFrame display: YES animate: YES];
}


// Combo Box Elements

- (IBAction) selectClassFrom: (id) sender
{
	Class selSource = [theSources objectForKey: [sender stringValue]];
	if (selSource != [theActiveSource class])
	{
		[theActiveSource release];
		theActiveSource = [[selSource alloc] init];
		[self refreshSourcePreferencesWindow: self];
	}
}

- (id)comboBox:(NSComboBox *)aComboBox objectValueForItemAtIndex:(int)index
{
	return [[[theSources allKeys] sortedArrayUsingSelector: @selector(compare:)] objectAtIndex: index];
}

- (int)numberOfItemsInComboBox:(NSComboBox *)aComboBox
{
	if (!theSources)
	{
		return 0;
	}
	unsigned retVal = [[theSources allKeys] count];
	[aComboBox setNumberOfVisibleItems: retVal];
	return retVal;
}

- (IBAction) switchABUsage: (id) sender
{
	useABDirectly = [theABUsageActivationButton state] == NSOnState;
	[self refreshABPeoplePicker];
}

- (void) refreshABPeoplePicker
{
	[theABPeoplePicker setHidden: !useABDirectly];
}

- (NSArray*) usersFromAB
{
	if (useABDirectly)
	{
		return theABUsers;
	}
	else
	{
		return NULL;
	}
}

#import <AddressBook/AddressBook.h>

- (void) DEBUG__blubbWithPeople: (NSArray*) people
{
	unsigned i;
	
	NSLog(@"Selected %d things", [people count]);
	
	for (i = 0; i < [people count]; ++i)
	{
		ABRecord* rec = [people objectAtIndex: i];
		if ([rec isKindOfClass: [ABPerson class]])
		{
			NSLog(@"DEBUG__AB: Selected %@", [rec valueForProperty: kABLastNameProperty]);
		}
		else if ([rec isKindOfClass: [ABGroup class]])
		{
			NSLog(@"There's a class named %@", [rec valueForProperty: kABGroupNameProperty]);
			[self DEBUG__blubbWithPeople: [(ABGroup*)rec members]];
		}
	}	
}

- (IBAction) DEBUG__testAB: (id) sender
{
	NSArray* recs = [theABPeoplePicker selectedRecords];
	if ([recs count] == 0)
	{
		recs = [theABPeoplePicker selectedGroups];
	}
	[self DEBUG__blubbWithPeople: recs];
	NSLog(@"%d Groups too?", [[theABPeoplePicker selectedGroups] count]);
}

@end
