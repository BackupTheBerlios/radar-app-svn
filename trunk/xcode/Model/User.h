//
//  User.h
//  Radar
//
//  Created by Daniel Reutter on 5/3/07.
//  Copyright 2007 Technische Universitaet Muenchen. All rights reserved.
//

/** @file User.h */

#import <Cocoa/Cocoa.h>
#import <AddressBook/AddressBook.h>

@interface User : NSObject {
	NSString* theName;
	NSString* theInfo;
	NSImage* theImage;
	id theSource;
	float theScore;
	NSPoint theLastPosition;
}


/// Initializes a basic user.
/** This is the most basic functional user object available. */
- (id) initWithName:	(NSString*) aName;

/// Initializes a basic user with image.
/** This user only consists of a name and an image. */
- (id) initWithName:	(NSString*) aName
		withImage:		(NSImage*) anImage;

/// Initializes with all available information for a user.
/** After initialization, all attributes are set to the parameters of this call. */
- (id) initWithName:	(NSString*) aName 
		withInfo:		(NSString*) anInfo 
		withImage:		(NSImage*) anImage 
		withSource:		(id) aSource;

- (id) initWithDictionary: (NSDictionary*) aDict;

//- (id) initWithABPerson: (ABPerson*) aPerson;

- (void) setScore: (float) newScore;
- (float) score;

- (void) setLastPosition: (NSPoint) newPos;
- (NSPoint) lastPosition;

- (NSComparisonResult)compareWith: (id) otherUser;

- (NSDictionary*) dictionary;

@end
