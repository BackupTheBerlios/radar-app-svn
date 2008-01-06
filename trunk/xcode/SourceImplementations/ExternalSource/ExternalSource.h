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
	/// NSTextField to edit the path to the external application
	IBOutlet NSTextField* theExternalAppPathField;
	/// NSTextField to edit the parameters given to the application
	IBOutlet NSTextField* theParametersField;
	
	/// NSString storing the path to the external application
	NSString* theExternalAppPath;
	
	/// NSMutableArray storing the parameters given to the application
	NSMutableArray* theParameters;
	
	/// NSString to the path in which to store the preferences
	@private NSString* ExternalSource__prefPath;
	
	/// NSArray containing User objects to score.
	/** Since the external application is executed in different threads than the main loop, users could be released
	  * before their score has been assigned to them. To prevent this, all User objects receive a
	  * retain message. These User objects are referenced in this array.
	  */
	NSArray* theUsersRetained;
	
	/// NSMutableArray containing the running tasks
	NSMutableArray* theTasks;
	
	/// id of the object to inform after complete score calculation
	id objectToInform;
	
	/// Message to send to objectToInform after complete score calculation
	SEL selectorToPerform;
}

/// Terminate all tasks
/** This method releases all tasks currently running to score the users.
  */
- (void)terminateAllTasks;

/// Informal protocol to inform that a task has ended.
/** The scoreUsers: method calls multiple threads to prevent hangups and speed up
  * the scoring process. After such thread ended, this message is sent to inform
  * the ExternalSource object about it.
  */
- (void)taskEnded: (NSNotification *)aNotification;

/// Inform the objectToInform by sending selectorToPerform if no tasks are left running
- (void)informIfAllTasksEnded;

@end
