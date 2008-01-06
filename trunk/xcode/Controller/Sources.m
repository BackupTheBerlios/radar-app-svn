//
//  Sources.m
//  Radar
//
//  Created by Daniel Reutter on 27.06.07.
//  Copyright 2007 Technische Universitaet Muenchen. All rights reserved.
//

#import "Sources.h"

#import "MailSource.h"
#import "ExternalSource.h"
#import "SVNSource.h"

@implementation Sources

+(NSDictionary*) sources
{
	return [NSDictionary dictionaryWithObjectsAndKeys: 
			[MailSource class], [MailSource sourceName],
			[ExternalSource class], [ExternalSource sourceName],
//			[SVNSource class], [SVNSource sourceName],
			nil];
}

@end
