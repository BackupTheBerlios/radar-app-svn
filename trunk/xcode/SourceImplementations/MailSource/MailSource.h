//
//  MailSource.h
//  Radar
//
//  Created by Daniel Reutter on 23.06.07.
//  Copyright 2007 Technische Universitaet Muenchen. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <Source.h>

@interface MailSource : Source {
	
	/// NSDatePicker to alter theEarliestDate
	IBOutlet NSDatePicker* theDatePicker;
	
	/// NSSlider to alter theScore
	IBOutlet NSSlider* theScoreSlider;
	
	/// NSTableView to alter theSelectedMailboxes
	IBOutlet NSTableView* theMailboxesTableView;
	
	/// NSMutableArray of all existing mailboxes
	NSMutableArray* mailboxes;
	
	/// NSDictionary of mailboxes to search for messages
	NSDictionary* theSelectedMailboxes;
	
	/// A float that represents the theoretical base score of a message sent NOW
	float theScore;
	
	/// A double representing the date in seconds since epoch prior to which a message does not count
	double theEarliestDate;
	
	/// NSString of the path to the MailSource preferences.
	@private NSString* MailSource__prefPath;
}

/// Reloads the mailboxes NSMutableArray
/** Since the lookup of the mailboxes may be tiring, this is not done every time the scoring takes place.
  * This method saves the existing mailboxes in the NSMutableArray.
  */
- (void)reloadTheMailboxes;

- (IBAction) deselectAll:(id)sender;

- (IBAction) selectAll:(id)sender;

/// Informal protocol method to display the mailboxes in theMailboxesTableView
- (id)tableView:(NSTableView *)aTableView
    objectValueForTableColumn:(NSTableColumn *)aTableColumn
			row:(int)rowIndex;

/// Informal protocol method returns the count of the mailboxes for theMailboxesTableView
- (int)numberOfRowsInTableView:(NSTableView *)aTableView;

/// Informal protocol method to register changes in theMailboxesTableView
- (void)tableViewSelectionDidChange:(NSNotification *)aNotification;

/// Informal protocol method returns TRUE to allow editing of table columns
- (BOOL)tableView:(NSTableView *)aTableView shouldEditTableColumn:(NSTableColumn *)aTableColumn row:(int)rowIndex;

/// Informal protocol method called when a selection is made in theMailboxesTableView
/** This method allows easier selection of multiple columns by clicking the value to (un-)select it.
  */
- (IBAction)selectRowInTableView:(id)sender;

@end
