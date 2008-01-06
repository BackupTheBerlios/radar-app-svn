//
//  MailSource.m
//  Radar
//
//  Created by Daniel Reutter on 23.06.07.
//  Copyright 2007 Technische Universitaet Muenchen. All rights reserved.
//

#include "Debug.h"

#import "MailSource.h"

// not the following
#import <CoreServices/CoreServices.h>

#import "QuickLiteGlobals.h"
#import "QuickLiteCursor.h"
#import "QuickLiteDatabaseExtras.h"
#import "sqliteInt.h"

#import "User.h"

#import "Debug.h"

#define MS__MailboxesTableURLString @"mailboxes.url"
#define MS__MailboxesTableROWIDString @"mailboxes.ROWID"

#define MS__ARYROWIDPOS 1
#define MS__ARYURLSTRINGPOS 0
#define MS__ARYSELECTEDPOS 2

#define MSPREF__SELECTEDMAILBOXES @"SelectedMailboxes"
#define MSPREF__EARLIESTDATE @"EarliestDate"
#define MSPREF__THESCORE @"Score"

@implementation MailSource

- (id) init
{
	DSetContext(@"MailSource init");
	self = [super init];
	if (self != nil)
	{
		[self SI__loadNibFileNamed: @"MailSourcePrefPane.nib"];
		thePreferencePaneTitle = @"Source: Mail";
		mailboxes = nil;
		MailSource__prefPath =  [[[NSString stringWithFormat: @"~/Library/Preferences/%@.%@", 
			[[[NSBundle mainBundle] infoDictionary] valueForKey: @"CFBundleIdentifier"], @"mailsource.plist"] stringByExpandingTildeInPath] retain];
		[self loadPreferences];
		
		DLog(@"Init of %@ succeeded.", self);
	}
	return self;
}

-(void)awakeFromNib
{
	[self initPreferencePane];
}

+(NSString*) sourceName
{
	return @"Mail Source";
}

- (void) scoreUsersInArray: (NSArray*) theUsers
					inform: (id) anObject
				 bySending: (SEL) aSelector
{
	DSetContext(@"scoreUsersInArray: inform: bySending:");
	DLog(@"Scoring users for %@ by Mail Source...", anObject);
	
	QuickLiteDatabase* db = [QuickLiteDatabase databaseWithFile: [@"~/Library/Mail/Envelope Index" stringByExpandingTildeInPath]];
	
	DLog(@"Loaded Database %@", db);
	
	if (![db open: NO
	  cacheMethod: CacheAllData])
	{
		DLog(@"Opening of db failed.");
		[anObject performSelector: aSelector];
		return;
	}
	
	DLog(@"Getting the selected mailboxes");
	NSMutableArray* selMboxes = [NSMutableArray arrayWithCapacity: [mailboxes count]];
	
	unsigned i;
	
	for (i = 0; i < [mailboxes count]; ++i)
	{
		if ([[[mailboxes objectAtIndex: i] objectAtIndex: MS__ARYSELECTEDPOS] boolValue])
		{
			[selMboxes addObject: [[mailboxes objectAtIndex: i] objectAtIndex: MS__ARYROWIDPOS]];
		}
	}
	
	DLog(@"Done with selecting mailboxes. Selected: %@", selMboxes);
	
//	NSMutableString* mailAddressesGlob = @"";
	NSMutableString* namesGlob = [NSMutableString string];
	
	[namesGlob appendFormat: @"(addresses.comment GLOB \"*%@*\")", 
		[[[[theUsers objectAtIndex: 0] valueForKey: @"theName"] componentsSeparatedByString: @" "] componentsJoinedByString: @"*"]];
	for (i = 1; i < [theUsers count]; ++i)
	{
		User* theUser = [theUsers objectAtIndex: i];
		// TODO: Get the mail addresses.
		[namesGlob appendFormat: @" OR (addresses.comment GLOB \"*%@*\")",
			[[[theUser valueForKey: @"theName"] componentsSeparatedByString: @" "] componentsJoinedByString: @"*"]];
	}
	
	DLog(@"namesGlob is %@", namesGlob);
	
	
//	NSString* sqlStatement = [NSString stringWithFormat: @"SELECT messages.date_sent,addresses.address,addresses.comment FROM messages,addresses WHERE ((messages.date_sent >= %d) AND (messages.sender = addresses.ROWID AND (%@) AND (messages.original_mailbox IN (%@)));", 
//		(int)theEarliestDate, namesGlob, [selMboxes componentsJoinedByString: @","]];
	
//	DLog(@"sqlStatement = %@", sqlStatement);
	
//	exit(0);
	
	DLog(@"Initiating Main Loop.");
	for (i = 0; i < [theUsers count]; ++i)
	{
//		DLog(@"MAILSOURCE MAIN SCORING LOOP BEGIN");
		User* theUser = [theUsers objectAtIndex: i];
//		DLog(@"Score for user %@", [theUser valueForKey: @"theName"]);
		NSString* nameGlob = [[[theUser valueForKey: @"theName"] componentsSeparatedByString: @" "] componentsJoinedByString: @"*"];
//		DLog(@"NameGlob is %@", nameGlob);
		NSString* sqlStatement = [NSString stringWithFormat: @"SELECT date_sent FROM messages WHERE (sender IN (SELECT ROWID FROM addresses WHERE comment GLOB \"*%@*\")) AND (original_mailbox IN (%@));", nameGlob, [selMboxes componentsJoinedByString: @","]];
//		DLog(@"SQL Statement is %@", sqlStatement);
		
//		DLog(@"Initiating query.");
		QuickLiteCursor* cursor = [db performQuery: sqlStatement];
//		DLog(@"Query performed.");
		
		if (cursor == nil)
		{
//			DLog(@"No database entries...");
			NSLog(@"No database entries.");
			continue;
		}
//		DLog(@"Database entries are %@", cursor);
		
		double totalScore = 0;
		double now = [[NSDate dateWithTimeIntervalSinceNow: 0.0] timeIntervalSince1970];
		
		unsigned j;
		
//		DLog(@"Counting Rows.");
		for (j = 0; j < [cursor rowCount]; ++j)
		{
//			DLog(@"Row number %d", j);
			double msgDate = [[[[cursor valuesForRow: j] allValues] objectAtIndex: 0] doubleValue];
			if (msgDate > theEarliestDate)
			{
				totalScore += theScore * (msgDate - theEarliestDate) / (now - theEarliestDate);
			}
//			DLog(@"Row done.");
		}
		
//		DLog(@"Got a score of %f.", totalScore);
		
		totalScore=(totalScore>1.0)?1.0:totalScore;
		
		[theUser setScore: totalScore];
//		DLog(@"MAILSOURCE MAIN SCORING LOOP END");
	}
	
	//[db release];
	DLog(@"About to release db...");
	[db closeSavingChanges: NO];
	DLog(@"Released.");
	
	DLog(@"Informing %@ about finishing the score.", anObject);
	[anObject performSelector: aSelector];

}

- (void)reloadTheMailboxes
{
	DSetContext(@"reloadTheMailboxes");
	DLog(@"Reading all mailboxes");
	QuickLiteDatabase* db = [QuickLiteDatabase databaseWithFile: [@"~/Library/Mail/Envelope Index" stringByExpandingTildeInPath]];
	
	if (![db open: NO
	  cacheMethod: CacheAllData])
	{
		return;
	}
	
	NSString* sqlStatement = @"SELECT * FROM mailboxes;";
	
	DLog(@"About to query sql statement %@", sqlStatement);
	
	DLog(@"Querying cursor now");
	QuickLiteCursor* cursor = [db performQuery: sqlStatement];
	DLog(@"Querying cursor done.");
	
	if (mailboxes != nil)
	{
		DLog(@"Releasing old mailboxes.");
		[mailboxes release];
		mailboxes = nil;
	}
	
	mailboxes = [NSMutableArray arrayWithCapacity: [cursor rowCount]];
	DLog(@"Mailboxes are %@", mailboxes);
	unsigned i;
	
	DLog(@"Commencing Loop");
	for (i = 0; i < [cursor rowCount]; ++i)
	{
//		DLog(@"Loop %d", i);
		NSDictionary* theRow = [cursor valuesForRow: i];
		
		NSString* theTableURLString = [theRow objectForKey: MS__MailboxesTableURLString];
		NSString* theROWIDString = [theRow objectForKey: MS__MailboxesTableROWIDString];
		
		NSNumber* theNumber = [theSelectedMailboxes objectForKey: theROWIDString];
		if (theNumber == nil)
		{
			theNumber = [NSNumber numberWithBool: TRUE];
		}
		
		NSMutableArray* theArray = [NSMutableArray arrayWithObjects:
			theTableURLString,
			theROWIDString,
			theNumber,
			nil];
		//		NSArray* theArray = [NSArray arrayWithObjects: [NSString stringWithString: @"123"], [NSString stringWithString: @"Bla"], [NSNumber numberWithBool: TRUE], nil];
//		DLog(@"Adding object %@ to mailboxes.", theArray);
		[mailboxes addObject: theArray];
//		DLog(@"Added.");
//		DLog(@"Loop %d done", i);
	}
	
	[db closeSavingChanges: NO];
	
	[mailboxes retain];
}

- (void)initPreferencePane
{
	[self reloadTheMailboxes];
	[theMailboxesTableView reloadData];

	[theScoreSlider setFloatValue: theScore];
	[theDatePicker setDateValue: [NSDate dateWithTimeIntervalSince1970: theEarliestDate]];
}

- (void)applyPreferencePaneSettings
{
	theScore = [theScoreSlider floatValue];
	theEarliestDate = [[theDatePicker dateValue] timeIntervalSince1970];
}

- (void)savePreferences
{
	DSetContext(@"Save Preferences");
	
	NSMutableDictionary* currentSettings = [NSMutableDictionary dictionaryWithContentsOfFile: MailSource__prefPath];
	
	currentSettings = currentSettings?currentSettings:[NSMutableDictionary dictionaryWithCapacity: 2];
	
	NSMutableDictionary* newSelected = [NSMutableDictionary dictionaryWithDictionary: theSelectedMailboxes];
	
	unsigned i;
	for (i = 0; i < [mailboxes count]; ++i)
	{
		[newSelected setValue: [[mailboxes objectAtIndex: i] objectAtIndex: MS__ARYSELECTEDPOS] 
					   forKey: [[mailboxes objectAtIndex: i] objectAtIndex: MS__ARYROWIDPOS]];
	}
	
	[currentSettings setValue: newSelected
					   forKey: MSPREF__SELECTEDMAILBOXES];
	
	
	if (theSelectedMailboxes != nil)
	{
		[theSelectedMailboxes release];
		theSelectedMailboxes = nil;
	}
	
	theSelectedMailboxes = [NSDictionary dictionaryWithDictionary: newSelected];
	
	[theSelectedMailboxes retain];
	
	[currentSettings setValue: [NSNumber numberWithFloat: theScore]
					   forKey: MSPREF__THESCORE];
	
	[currentSettings setValue: [NSDate dateWithTimeIntervalSince1970: theEarliestDate]
					   forKey: MSPREF__EARLIESTDATE];
	
	[currentSettings writeToFile: MailSource__prefPath
					  atomically: YES];
}

- (void)loadPreferences
{
	NSDictionary* currentSettings = [NSDictionary dictionaryWithContentsOfFile: MailSource__prefPath];
	
	if (theSelectedMailboxes != nil)
	{
		[theSelectedMailboxes release];
		theSelectedMailboxes = nil;
	}
	
	theSelectedMailboxes = [currentSettings objectForKey: MSPREF__SELECTEDMAILBOXES];
	[theSelectedMailboxes retain];
	[self reloadTheMailboxes];
		
	if ([currentSettings objectForKey: MSPREF__THESCORE])
	{
		theScore = [[currentSettings objectForKey: MSPREF__THESCORE] floatValue];
	}
	else
	{
		theScore = 0.2;
	}
	
	if ([currentSettings objectForKey: MSPREF__EARLIESTDATE])
	{
		theEarliestDate = [[currentSettings objectForKey: MSPREF__EARLIESTDATE] timeIntervalSince1970];
	}
	else
	{
		theEarliestDate = [[NSDate dateWithTimeIntervalSinceNow: -60.0*60.0*24.0*14.0] timeIntervalSince1970];
	}
}

- (id)tableView:(NSTableView *)aTableView
    objectValueForTableColumn:(NSTableColumn *)aTableColumn
			row:(int)rowIndex
{
	if (mailboxes == nil)
	{
		return nil;
	}
	if ([@"SelectColumn" compare: [aTableColumn identifier]] == NSOrderedSame)
	{
		return [[mailboxes objectAtIndex: rowIndex] objectAtIndex: MS__ARYSELECTEDPOS];
	}
	else
	{
		return [[mailboxes objectAtIndex: rowIndex] objectAtIndex: MS__ARYURLSTRINGPOS];
	}
}

- (int)numberOfRowsInTableView:(NSTableView *)aTableView
{
	return [mailboxes count];
}

- (void)tableViewSelectionDidChange:(NSNotification *)aNotification
{
//	NSLog(@"Selection did change: %@", aNotification);
}

- (BOOL)tableView:(NSTableView *)aTableView shouldEditTableColumn:(NSTableColumn *)aTableColumn row:(int)rowIndex
{
	return TRUE;
}

- (IBAction)selectRowInTableView:(id)sender
{
	NSNumber* theValue = [NSNumber numberWithBool: ![[[mailboxes objectAtIndex: [sender selectedRow]] objectAtIndex: MS__ARYSELECTEDPOS] boolValue]];
	[[mailboxes objectAtIndex: [sender selectedRow]] replaceObjectAtIndex: MS__ARYSELECTEDPOS withObject: theValue];
}

@end
