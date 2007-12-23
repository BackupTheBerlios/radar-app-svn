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
	IBOutlet NSDatePicker* theDatePicker;
	IBOutlet NSSlider* theScoreSlider;
	IBOutlet NSTableView* theMailboxesTableView;

	NSMutableArray* mailboxes;
	
	NSDictionary* theSelectedMailboxes;
	float theScore;
	double theEarliestDate;
	
	@private NSString* MailSource__prefPath;
}

- (void)reloadTheMailboxes;

- (id)tableView:(NSTableView *)aTableView
    objectValueForTableColumn:(NSTableColumn *)aTableColumn
			row:(int)rowIndex;

- (int)numberOfRowsInTableView:(NSTableView *)aTableView;

- (void)tableViewSelectionDidChange:(NSNotification *)aNotification;

- (BOOL)tableView:(NSTableView *)aTableView shouldEditTableColumn:(NSTableColumn *)aTableColumn row:(int)rowIndex;

- (IBAction)selectRowInTableView:(id)sender;

@end
