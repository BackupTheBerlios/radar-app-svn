/*
 *  Debug.h
 *  Radar
 *
 *  Created by Daniel Reutter on 07.07.07.
 *  Copyright 2007 __MyCompanyName__. All rights reserved.
 *
 */


/// The RADAR__DEBUG define controls the debug output.
#ifdef RADAR__DEBUG // Debug is ON

#import <Carbon/Carbon.h>

@class NSString;

#define DSetContext(prefix) NSString* __DEBUG__context__ = [NSString stringWithFormat: @"%@ - %@", self, prefix]
#define DLog(...) _DLog(__DEBUG__context__, __LINE__, __FILE__, __VA_ARGS__)
void _DLog(NSString* context, unsigned line, char* file, NSString* fmt, ...);

#else // Debug is OFF

#define DSetContext(prefix) do{}while(0)
#define DLog(args...) do{}while(0)

#endif