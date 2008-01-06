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

/// Initializes the user with the contents of aDict
/** The aDict NSDictionary contains key/value pairs of all members of the new user object.
  */
- (id) initWithDictionary: (NSDictionary*) aDict;

//- (id) initWithABPerson: (ABPerson*) aPerson;

/// Sets the score to newScore
/** Each user has a score that represents the value of the persona represented by the user
  * relative to a certain Source.
  */
- (void) setScore: (float) newScore;

/// Returns the user's score
/** Each user has a score that represents the value of the persona represented by the user
 * relative to a certain Source.
 */
- (float) score;

/// Sets the last position to newPos
/** When displaying a persona, the last position of it may be relevant to prevent fluctuation
  * in the AvatarView.
  */
- (void) setLastPosition: (NSPoint) newPos;

/// Returns the user's last position
/** When displaying a persona, the last position of it may be relevant to prevent fluctuation
 * in the AvatarView.
 */
- (NSPoint) lastPosition;

/// Method to compare two users with each other
/** A user is considered to be before another user if her score is higher than the other user's score.
  */
- (NSComparisonResult)compareWith: (id) otherUser;

/// Return the user's member as a dictionary
/** This method returns all relevant members of her stored in key/value pairs.
  * This NSDictionary can be used with the initWithDictionary initialization.
  */
- (NSDictionary*) dictionary;

@end
