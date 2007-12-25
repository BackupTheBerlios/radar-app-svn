/*
 *  Debug.c
 *  Radar
 *
 *  Created by Daniel Reutter on 07.07.07.
 *  Copyright 2007 __MyCompanyName__. All rights reserved.
 *
 */

#import "Debug.h"

#ifdef RADAR__DEBUG

void _DLog(NSString* context, NSString* fmt, ...)
{
	va_list ap;
	va_start(ap, fmt);
	
	NSString* theText =[context stringByAppendingString: fmt];
	
	NSLogv(theText, ap);
}
#endif