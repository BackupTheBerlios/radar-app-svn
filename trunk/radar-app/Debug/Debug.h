/*
 *  Debug.h
 *  Radar
 *
 *  Created by Daniel Reutter on 07.07.07.
 *  Copyright 2007 __MyCompanyName__. All rights reserved.
 *
 */

#import <Carbon/Carbon.h>

@class NSString;

#ifdef RADAR__DEBUG
#define DSetContext(prefix) NSString* __DEBUG__context__ = [NSString stringWithFormat: @"<DEBUG> %@ - %@ : ", self, prefix]

#define DLog(...) _DLog(__DEBUG__context__, __VA_ARGS__)
void _DLog(NSString* context, NSString* fmt, ...);
#else
inline void DSetContext(NSString* prefix) {};
inline void DResetContext() {};
inline void DLog(NSString* fmt, ...) {};
#endif