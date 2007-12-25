//
//  ExternalSource.m
//  Radar
//
//  Created by Daniel Reutter on 23.06.07.
//  Copyright 2007 Technische Universitaet Muenchen. All rights reserved.
//

#import "ExternalSource.h"
#import "User.h"

#define ESPREF__APPLICATIONPATH @"ApplicationPath"
#define ESPREF__PARAMETERARRAY  @"Parameters"

@implementation ExternalSource

+(NSString*) sourceName
{
	return @"External Source";
}

- (id) init
{
	self = [super init];
	if (self != nil)
	{
		[self SI__loadNibFileNamed: @"ExternalSourcePrefPane.nib"];
		thePreferencePaneTitle = @"Source: External";
		ExternalSource__prefPath =  [[[NSString stringWithFormat: @"~/Library/Preferences/%@.%@", 
			[[[NSBundle mainBundle] infoDictionary] valueForKey: @"CFBundleIdentifier"], @"externalsource.plist"] stringByExpandingTildeInPath] retain];
		[self loadPreferences];
		[[NSNotificationCenter defaultCenter] addObserver: self 
												 selector: @selector(taskEnded:)
													 name: NSTaskDidTerminateNotification
												   object: nil];
	}
	return self;
}

- (void) scoreUsersInArray: (NSArray*) theUsers
					inform: (id) anObject
				 bySending: (SEL) aSelector
{
	NSString* path = [theExternalAppPath stringByExpandingTildeInPath];
	NSMutableArray* taskDict = [NSMutableArray arrayWithCapacity: [theUsers count]];
	
	unsigned userIndex, paramIndex;
	
	if (theUsersRetained != nil)
	{
		[theUsersRetained release];
		theUsersRetained = nil;
	}
	theUsersRetained = [[NSArray arrayWithArray: theUsers] retain];

	if (![[NSFileManager defaultManager] isExecutableFileAtPath: path])
	{
		NSLog (@"Can't execute %@.", path); // KEEP THIS LOG
	}
	
	for (userIndex = 0; userIndex < [theUsersRetained count]; ++userIndex)
	{
		NSMutableArray* params = [NSMutableArray arrayWithArray: theParameters];
		
		User* theUser = [theUsersRetained objectAtIndex: userIndex];
		while ((paramIndex = [params indexOfObject: @"%name%"]) != NSNotFound)
		{
			[params replaceObjectAtIndex: paramIndex withObject: [theUser valueForKey: @"theName"]];
		}
		
		NSTask* task = [[NSTask alloc] init];
		[task setLaunchPath: path];
		[task setArguments: params];
		
		NSPipe* pipe = [[NSPipe pipe] retain];
		[task setStandardOutput: pipe];
		
		[task launch];
		
		[taskDict insertObject: task atIndex: userIndex];
	}
	if (theTasks != nil)
	{
		[self terminateAllTasks];
	}
	theTasks = [[NSMutableArray arrayWithArray: taskDict] retain];
	objectToInform = anObject;
	selectorToPerform = aSelector;
}

- (void)terminateAllTasks
{
	if (theTasks != nil)
	{
		[theTasks release];
		theTasks = nil;
	}
}

- (void)initPreferencePane
{
	[theParametersField setStringValue: [theParameters componentsJoinedByString: @" "]];
	
	[theExternalAppPathField setStringValue: theExternalAppPath];
}

- (void)applyPreferencePaneSettings
{
	theExternalAppPath = [theExternalAppPathField stringValue];
	[theParameters setArray: [[theParametersField stringValue] componentsSeparatedByString: @" "]];
}

- (void)savePreferences
{
	NSMutableDictionary* currentSettings = [NSMutableDictionary dictionaryWithContentsOfFile: ExternalSource__prefPath];
	
	currentSettings = currentSettings?currentSettings:[NSMutableDictionary dictionaryWithCapacity: 2];
	
	[currentSettings setValue: theExternalAppPath forKey: ESPREF__APPLICATIONPATH];
	[currentSettings setValue: theParameters forKey: ESPREF__PARAMETERARRAY];
	[currentSettings writeToFile: ExternalSource__prefPath
					  atomically: YES];
}

- (void)loadPreferences
{
	NSDictionary* currentSettings = [NSDictionary dictionaryWithContentsOfFile: ExternalSource__prefPath];

	theExternalAppPath = [[currentSettings valueForKey: ESPREF__APPLICATIONPATH] retain];
	theExternalAppPath = theExternalAppPath?theExternalAppPath:@"";
	
	if (!theParameters)
	{
		theParameters = [[NSMutableArray arrayWithCapacity: 1] retain];
	}
	[theParameters setArray: [currentSettings valueForKey: ESPREF__PARAMETERARRAY]];
}

-(void) taskEnded: (NSNotification *)aNotification
{
	NSTask* endedTask = [aNotification object];
	unsigned userIndex = [theTasks indexOfObject: endedTask];
	
	if (userIndex == NSNotFound)
	{
		return;
	}
		
	NSData *data;
    data = [[[endedTask standardOutput] fileHandleForReading] readDataToEndOfFile];
	
    NSString *string;
    string = [[NSString alloc] initWithData: data encoding: NSUTF8StringEncoding];
	
	[[theUsersRetained objectAtIndex: userIndex] setScore: [string floatValue]];

	[theTasks replaceObjectAtIndex: userIndex 
						withObject: [NSNull null]];
	[endedTask release];
	[self informIfAllTasksEnded];
}

- (void) informIfAllTasksEnded
{
	unsigned i;
	BOOL allTasksEnded = TRUE;
	
	for (i = 0; i < [theTasks count]; ++i)
	{
		allTasksEnded = allTasksEnded && ([[theTasks objectAtIndex: i] isEqual: [NSNull null]]);
	}
	
	if (allTasksEnded)
	{
		[self terminateAllTasks];
		[objectToInform performSelector: selectorToPerform];
		[theUsersRetained release];
		theUsersRetained = nil;
	}
}

@end
