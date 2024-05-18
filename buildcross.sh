#!/bin/sh
###############################################################################
# Copyright 2000-2012
#         Harley Laue (losinggeneration@gmail.com) and others (as noted).
#         All rights reserved.
###############################################################################
# If you want to use #!/bin/zsh, you must add -y onto the end as this script
# requires that functionality. -y is as of this writting --shwordsplit
###############################################################################
# Most UNIX based systems should have most all of this.
# Depends on bash, sed, mv, cp, ln, pwd, rm, mkdir, grep, touch, and of course
# a working development system (gcc, binutils, make, texinfo, etc)
#
# Also wget to download files and svn to get KOS
###############################################################################
# How to add another target:
# Required:
# 1) Add the options you need to a file of the name of the target and set up
#    the options using one of the other targets as a template.
# 2) Add target name to ParseArgs and have it call SetOptions with the filename
#    as an option
# Optional:
# 3) Add your target to Usage()
###############################################################################
BUILDCROSS_VERSION=1.9.0
# To reduce clutter I've moved functions into separate files.
# These will include the functions so we can call them from  here.
###############################################################################

[ -f ".env" ] && . ./.env

# utilities include making directories, downloading, patching etc
. ./utilities.sh

# Options Parser, Usage, and Examples
. ./options.sh

# how to configure/build each (Binutils, Gcc, Newlib, uClibc, & KOS)
. ./build.sh

###############################################################################
# Our main function because I like C-like code
###############################################################################
main()
{
	# check if colors can be on by default
	check_echo
	# Set up some things the user wont ever need to
	# Default to $SYSTEM options
	#SetOptions $SYSTEM

	# Check if there aren't any arguments
	if [ $# -le 0 ]; then
		# No arguments so print usage and quit
		Usage
		exit
	fi

	# Go through each argument that was given
	for i in $*; do
		if ! ParseArgs $i; then
			LogError "Ignoring unsupported argument \"$i\"";
		fi
	done
}

###############################################################################
# Just call main and be done with it
###############################################################################
main $@

