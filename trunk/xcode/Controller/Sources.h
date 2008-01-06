//
//  Sources.h
//  Radar
//
//  Created by Daniel Reutter on 27.06.07.
//  Copyright 2007 Technische Universitaet Muenchen. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "Source.h"

/** @File: This class should never be implemented. It only offers a convenient way to 
  * add or remove children of the Source class that are selectable in the preference pane.
  */

@interface Sources : NSObject {

}

+(NSDictionary*) sources;

@end
