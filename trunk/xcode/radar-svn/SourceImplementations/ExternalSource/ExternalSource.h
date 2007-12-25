//
//  ExternalSource.h
//  Radar
//
//  Created by Daniel Reutter on 23.06.07.
//  Copyright 2007 Technische Universitaet Muenchen. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <Source.h>

@interface ExternalSource : Source {
	IBOutlet NSTextField* theExternalAppPathField;
	IBOutlet NSTextField* theParametersField;
	
	NSString* theExternalAppPath;
	
	NSMutableArray* theParameters;
	
	@private NSString* ExternalSource__prefPath;
	
	NSArray* theUsersRetained;
	NSMutableArray* theTasks;
	id objectToInform;
	SEL selectorToPerform;
}

- (void)terminateAllTasks;
- (void)taskEnded: (NSNotification *)aNotification;
- (void)informIfAllTasksEnded;

@end
