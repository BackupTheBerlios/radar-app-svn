/*
 *  Defines.h
 *  Radar
 *
 *  Created by Daniel Reutter on 08.06.07.
 *  Copyright 2007 Technische Universitaet Muenchen. All rights reserved.
 *
 */

/// Definition for the new user NSButton tag in NSSegmentedCell
#define SEGMENT_NEW_USER_TAG		1705
/// Definition for the edit user NSButton tag in NSSegmentedCell
#define SEGMENT_EDIT_USER_TAG		1735
/// Definition for the remove user NSButton tag in NSSegmentedCell
#define SEGMENT_REMOVE_USER_TAG		1775
/// Definition for the tag for NSTableView displaying only permanent users
#define PERMANENT_USER_TABLEVIEW	1178
/// Definition for the tag for NSTableView displaying all users
#define COMPLETE_USER_TABLEVIEW		1177
/// Definition for the tag for the apply button, as opposed to the OK button
#define BUTTON_ADD_USER_APPLY_TAG	55

// Exception Name Definitions

/// Exception name definition to throw when a virtual method is called.
#define VirtualMethodException @"Virtual Method Exception"	
