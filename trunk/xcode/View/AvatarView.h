//
//  AvatarView.h
//  Radar
//
//  Created by Daniel Reutter on 5/17/07.
//  Copyright 2007 Technische Universitaet Muenchen. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class UserFactory;

@interface AvatarView : NSView
{
	IBOutlet UserFactory* theUserFactory;
}

@end
