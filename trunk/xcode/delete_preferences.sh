#!/bin/sh

# delete_preferences.sh
# Radar
#
# Created by Daniel Reutter on 09.01.08.
# Copyright 2008 __MyCompanyName__. All rights reserved.

# Delete the preferences
rm -f ~/Library/Preferences/edu.tum.cs.radar.*

# Delete the application support directory
rm -rf ~/Library/Application\ Support/Radar/
