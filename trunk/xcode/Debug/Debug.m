/*
 *  Debug.c
 *  Radar
 *
 *  Created by Daniel Reutter on 07.07.07.
 *  Copyright 2007 Techinsche Universitaet Muenchen. All rights reserved.
 *
 */

#import "Debug.h"

#ifdef RADAR__DEBUG

#import <Cocoa/Cocoa.h>

static BOOL __DEBUG__firstRun = YES;
void _DLog(NSString* context, unsigned line, char* file, NSString* fmt, ...)
{
	va_list ap;
	va_start(ap, fmt);
	
	if(__DEBUG__firstRun)
	{
		NSLog(@"[DEBUG] Radar.app debugging is ON! Look for [DEBUG LINE <number> FILE <path>] in the console output.");
		__DEBUG__firstRun = NO;
	}
	
	NSString* theText = [NSString stringWithFormat: @"[DEBUG LINE %d FILE %s] %@: %@", line, file, context, fmt];
//	NSString* theText =[context stringByAppendingString: fmt];
	
	NSLogv(theText, ap);
}
#endif