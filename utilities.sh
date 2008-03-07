#!/bin/sh
###############################################################################
# Copyright 2000-2007
#         Harley Laue (losinggeneration@yahoo.com) and others (as noted).
#         All rights reserved.
###############################################################################
# Used for checking things in the code. Used with silent most the time so it's
# easy to see debug messages.
###############################################################################
Debug()
{
	echo -e "${TEXTPREFIX}debug:: $TEXTDEBUG$*$TEXTRESET"
}

###############################################################################
# To shorten code, ExecuteCmd will redirect output if needed and execute
# Result after executing the command
# Takes the form of ExecuteCmd "Commands to execute" "Message to display"
# "Message to display" can be left off to display the command instead of the
# message in Result
# NOTE:
# 	This can't handle redirection of commands like:
#	sed "s/test/test2/" > output
#	Those commands must be done as normal commands and not through this
###############################################################################
ExecuteCmd()
{
	# This must be done this way instead of having this below with Result
	# instead of OUTPUT= because then if the last command is the if
	# statement and not the command. So either do this first, or store the
	# value from the command temporarily. I chose to store what output was
	# first. Price I pay for allowing one or two arguments to the function
	local OUTPUT=""
	if [ "$2" ]; then
		OUTPUT=$2
	else
		OUTPUT=$1
	fi

	if [ "$SILENT" -eq 0 ]; then
		$1
	else
		$1 >> $SENDTOWHERE 2>> $ERRORTOWHERE
	fi

	Result $OUTPUT
}

###############################################################################
# Same as above but only LogErrors/Fatals and inlines Result
###############################################################################
QuietExec()
{
	if [ "$SILENT" -eq 0 ]; then
		$1
	else
		$1 >> $SENDTOWHERE 2>> $ERRORTOWHERE
	fi

	if [ $? -ne 0 ]; then
		LogError "$* $TEXTFAILED"
		LogFatal "Failed to complete sucessfully. Exiting script."
	fi
}

###############################################################################
# See if a command like make exited cleanly
###############################################################################
Result() 
{
	# I assume the programmers use 0 for success and other values for not
	if [ $? -eq 0 ]; then
		LogOutput "$* $TEXTCOMPLETED"
	else
		LogError "$* $TEXTFAILED"
		LogFatal "Failed to complete successfully. Exiting script."
	fi
}

###############################################################################
# Logs title output if needed and always prints the title to the screen
###############################################################################
LogTitle()
{
	echo -e "$TEXTPREFIX## $TEXTTITLE$*$TEXTRESET"
	if [ $SILENT -ne 0 ]; then
		echo "## $*" >> $SENDTOWHERE
	fi
}

###############################################################################
# Logs output if needed or just echos it to screen
###############################################################################
LogOutput()
{
	if [ $SILENT -eq 0 ]; then
		echo -e "$TEXTPREFIX:: $TEXTOUTPUT$*$TEXTRESET"
	else
		echo ":: $*" >> $SENDTOWHERE
	fi
}

###############################################################################
# Logs errors if needed or just echos it to screen
###############################################################################
LogError()
{
	echo -e "$TEXTPREFIX!! $TEXTERROR$*$TEXTRESET"
	if [ $SILENT -ne 0 ]; then
		echo "!! $*" >> $ERRORTOWHERE
	fi
}

###############################################################################
# Logs an error, and exits
###############################################################################
LogFatal()
{
	LogError "$*"
	exec false
}

###############################################################################
# Create directories to build in
###############################################################################
CreateDir()
{
	if [ ! -d $BINBUILD ]; then
		QuietExec "mkdir -p $BINBUILD"
	fi

	if [ ! -d $GCCBUILD ]; then
		QuietExec "mkdir -p $GCCBUILD"
	fi

	if [ ! -d $NEWLIBBUILD ]; then
		QuietExec "mkdir -p $NEWLIBBUILD"
	fi
}

###############################################################################
# 1) Try to create directories if needed
# 2) If untar returns true than patch it
# Otherwise it does nothing
# $1 is the source directory name
# $2-$* is the patches (Gcc, Binutils, Newlib, Kos, Kos Ports)
###############################################################################
UntarPatch()
{
	CreateDir

	# check if the directory for the source exists
	# and that we got to touch that it's untared
	if [ ! -d $TARG/$1 -o ! -e $TARG/$1/.untared ]; then
		Untar $1
	fi

	# We send all parameters because the first is $1 and the rest
	# are the patches, the format we want.
	Patch $*
}

###############################################################################
# Untar the source if needed
###############################################################################
Untar()
{
	# Make sure to it's downloaded
	Download $1

	# Now check if the tar.bz2 file exists
	if ! CheckExists $1.tar.bz2; then
		# if it doesn't try for tar.gz
		if CheckExists $1.tar.gz; then
			# We have the tar.gz hooray
			ExecuteCmd "tar xfz $1.tar.gz -C $TARG" "Untaring $1.tar.gz"
		fi
	elif CheckExists $1.tar.bz2; then
		# Well we have the tar.bz2 good job
		ExecuteCmd "tar xfj $1.tar.bz2 -C $TARG" "Untaring $1.tar.bz2"
	else
		LogFatal "Cannot untar $1.tar.bz2 or $1.tar.gz. Make sure .$1-downloaded doesn't exist or the file might be corrupt. If you do get this message tell me how, because it seems like it shouldn't ever come up."
	fi

	# A quick way to tell if we need to untar or not
	QuietExec "touch $TARG/$1/.untared"
}

###############################################################################
# Download the file
###############################################################################
Download()
{
	case $1 in
		"$BINVER")
			if ! CheckExists .$BINVER-downloaded || ! CheckExists $BINVER.tar.bz2 ; then
				ExecuteCmd "wget -c ftp://ftp.gnu.org/gnu/binutils/$BINVER.tar.bz2"
				QuietExec "touch .$BINVER-downloaded"
			fi
			;;
		"$GCCVER")
			if ! CheckExists .$GCCVER-downloaded || ! CheckExists $GCCVER.tar.bz2; then
				ExecuteCmd "wget -c ftp://ftp.gnu.org/gnu/gcc/$GCCVER/$GCCVER.tar.bz2"
				QuietExec "touch .$GCCVER-downloaded"
			fi
			;;
		"$NEWLIBVER")
			if ! CheckExists .$NEWLIBVER-downloaded || ! CheckExists $NEWLIBVER.tar.gz; then
				ExecuteCmd "wget -c ftp://sources.redhat.com/pub/newlib/$NEWLIBVER.tar.gz"
				QuietExec "touch .$NEWLIBVER-downloaded"
			fi
			;;
		"$UCLIBCVER")
			if ! CheckExists .$UCLIBCVER-downloaded || ! CheckExists $UCLIBCVER.tar.bz2; then
				if [ $(echo $UCLIBCVER | grep snapshot) ]; then
					ExecuteCmd "wget -c http://uclibc.org/downloads/snapshots/$UCLIBCVER.tar.bz2"
				elif [ $(echo $UCLIBCVER | grep "\." ) ]; then
					ExecuteCmd "wget -c http://uclibc.org/downloads/$UCLIBCVER.tar.bz2"
				else
					QuietExec "cd $TARG"
					ExecuteCmd "svn co svn://uclibc.org/trunk/uClibc"
					QuietExec "cd .."
				fi
				QuietExec "touch .$UCLIBCVER-downloaded"
			fi
			;;
		"$GLIBCVER")
			if ! CheckExists .$GLIBCVER-downloaded || ! CheckExists $GLIBCVER.tar.bz2; then
				ExecuteCmd "wget -c ftp://ftp.gnu.org/gnu/glibc/$GLIBCVER.tar.bz2"
				QuietExec "touch .$GLIBCVER-downloaded"
			fi
			;;
		"$KERNELVER")
			if ! CheckExists .$KERNELVER-downloaded || ! CheckExists $KERNELVER.tar.bz2; then
				if [ $(echo $KERNELVER | grep libc) ]; then
					ExecuteCmd "wget -c http://ep09.pld-linux.org/~mmazur/linux-libc-headers/$KERNELVER.tar.bz2"
				else
					ExecuteCmd "wget -c http://www.kernel.org/pub/linux/kernel/v2.6/$KERNELVER.tar.bz2"
				fi
				QuietExec "touch .$KERNELVER-downloaded"
			fi
			;;
		"kos")
			if ! CheckExists $KOSLOCATION/.kos-downloaded || ! test -d $KOSLOCATION; then
				QuietExec "cd $KOSLOCATION/.."
				ExecuteCmd "svn co https://cadcdev.svn.sourceforge.net/svnroot/cadcdev/kos"
				QuietExec "touch .kos-downloaded"
			fi
			if ! CheckExists $KOSLOCATION/../kos-ports/.kos-ports-downloaded || ! test -d $KOSLOCATION/../kos-ports; then
				QuietExec "cd $KOSLOCATION/.."
				ExecuteCmd "svn co https://cadcdev.svn.sourceforge.net/svnroot/cadcdev/kos-ports"
				QuietExec "touch .kos-ports-downloaded"
			fi
			QuietExec "cd $BASEDIR"
			;;
		*)
			LogFatal "Script problem, contact maintainer to fix ;-)"
			;;
	esac
}

###############################################################################
# Try to patch the file
# $1 is the patches
# $2 is the source directory to be patched
###############################################################################
Patch()
{
	if [ $1 == "kos" ]; then
		LOC=$KOSLOCATION
	elif [ $1 == "kos-ports" ]; then
		LOC=$KOSLOCATION/../kos-ports
	else
		LOC=$BASEDIR/$TARG/$1
	fi
	# We need to get past the name/version so shift the params one
	shift 1

	if ! CheckExists $LOC/.patched; then
		QuietExec "cd $LOC"
		# Go through all parameters passed here which is
		# $(ls patches/sys/namever-*)
		for i in $*; do
			# Only patch if the "if" includes a *.patch or a *.diff
			if [ "`echo $i | grep -i '\.patch' | grep -v DISABLED`" -o \
					"`echo $i | grep -i '\.diff' | grep -v DISABLED`" ]; then
				ExecuteCmd "patch -p1 -i $i"
			fi
		done

		QuietExec "touch .patched"
		QuietExec "cd $BASEDIR"
	fi
}

###############################################################################
# Remove the contents of a directory
###############################################################################
Remove()
{
	CheckSystem
	LogOutput "Removing contents of $BASEDIR/$1/* $BASEDIR/$1/.*config* $BASEDIR/$1/.*installed*"
	ExecuteCmd "rm -fr $BASEDIR/$1/* $BASEDIR/$1/.*config* $BASEDIR/$1/.*installed*" "Removing $1"
}

###############################################################################
# Remove the contents of a directory, but leave that if it's been built or not
###############################################################################
CleaningRemove()
{
	CheckSystem
	LogTitle "Removing contents of $BASEDIR/$1/*"
	ExecuteCmd "rm -fr $BASEDIR/$1/*" "Removing contents of $BASEDIR/$1/*"
}

###############################################################################
# Clean the install directory
###############################################################################
CleanInstall()
{
	CheckSystem
	LogTitle "Cleaning $INSTALL"
	ExecuteCmd "rm -fr $INSTALL/*" "Cleaning $INSTALL"
}

###############################################################################
# Clean the local directories
###############################################################################
CleanLocal()
{
	CheckSystem
	LogTitle "Cleaning $BASEDIR Build files"
	Remove $BINBUILD
	Remove $GCCBUILD
	Remove $NEWLIBBUILD
	if [ "$UCLIBCDIR" ]; then
		Remove $UCLIBCDIR
	fi
	if [ "$GLIBCDIR" ]; then
		Remove $GLIBCDIR
	fi
}

###############################################################################
# Checks to make sure a system has been selected
###############################################################################
CheckSystem()
{
	if [ ! "$SYSTEM" ]; then
		LogFatal "You must select a system!"
	fi
}

###############################################################################
# Check to see if file exists
###############################################################################
CheckExists()
{
	# It returns 0 so you can do "if CheckExists filename;" to check if
	# the file exists, and it looks more correct to me
	#
	# It has to be this way since "if function;" is executes the "if" if
	# the function returns 0 (success, think of programs exiting
	# successfully return 0) or 1 (a program failing). So this function has
	# to behave like a mini program returning 0 on success and 1 on a
	# failure.
	if [ -e $1 ]; then
		# Exists, return 0
		return 0
	fi

	# Doesn't exist, return 1
	return 1
}

###############################################################################
# Mainly used to prepare for a release by cleaning all downloaded files and
# removing all target directories.
###############################################################################
DistClean()
{
	# I'd hate to see this in any other directory
	QuietExec "cd $BASEDIR"
	find . -name "*~" -exec rm {} \;
	ExecuteCmd "rm -fr .linux-* .binutils-* .gcc-* .uClibc-* .newlib-* *.bz2 *.gz"
	SetOptions Dreamcast
	ExecuteCmd "rm -fr $TARG"
	SetOptions Gamecube
	ExecuteCmd "rm -fr $TARG"
	SetOptions DcLinux
	ExecuteCmd "rm -fr $TARG"
	SetOptions Genesis
	ExecuteCmd "rm -fr $TARG"
	SetOptions GcLinux
	ExecuteCmd "rm -fr $TARG"
	SetOptions Ix86
	ExecuteCmd "rm -fr $TARG"
}

###############################################################################
# Check dependencies
###############################################################################
CheckDeps()
{
	if test ! "$(./config.guess | grep -i linux)"; then
		LogFatal "Sorry, Checking for dependencies is only known to work in Linux... for now"
	fi

	# If a dependency is not found, it's put in this variable
	local NOTFOUND=""

	if ! DependsResult "sed"; then
		NOTFOUND= "sed"
	fi

	if ! DependsResult "mv"; then
		# Keep the list when adding a new missing dep
		NOTFOUND="$NOTFOUND, mv"
	fi

	if ! DependsResult "cp"; then
		NOTFOUND="$NOTFOUND, cp"
	fi

	if ! DependsResult "ln"; then
		NOTFOUND="$NOTFOUND, ln"
	fi

	if ! DependsResult "pwd"; then
		NOTFOUND="$NOTFOUND, pwd"
	fi

	if ! DependsResult "rm"; then
		NOTFOUND="$NOTFOUND, rm"
	fi

	if ! DependsResult "mkdir"; then
		NOTFOUND="$NOTFOUND, mkdir"
	fi

	if ! DependsResult "grep"; then
		NOTFOUND="$NOTFOUND, grep"
	fi

	if ! DependsResult "touch"; then
		NOTFOUND="$NOTFOUND, touch"
	fi

	if ! DependsResult "gcc"; then
		NOTFOUND="$NOTFOUND, gcc"
	fi

	if ! DependsResult "ar"; then
		NOTFOUND="$NOTFOUND, binutils"
	fi

	if ! DependsResult "make"; then
		NOTFOUND="$NOTFOUND, make"
	fi

	if ! DependsResult "makeinfo"; then
		NOTFOUND="$NOTFOUND, texinfo"
	fi

	if ! DependsResult "gzip"; then
		NOTFOUND="$NOTFOUND, gzip"
	fi

	if ! DependsResult "bunzip2"; then
		NOTFOUND="$NOTFOUND, bunzip2"
	fi

	if ! DependsResult "patch"; then
		NOTFOUND="$NOTFOUND, patch"
	fi

	if ! DependsResult "awk"; then
		NOTFOUND="$NOTFOUND, awk"
	fi

	if ! DependsResult "diff"; then
		NOTFOUND="$NOTFOUND, diff"
	fi

	if ! DependsResult "wget"; then
		NOTFOUND="$NOTFOUND, wget"
	fi

	if ! DependsResult "svn"; then
		NOTFOUND="$NOTFOUND, svn"
	fi

	if ! DependsResult "flex"; then
		NOTFOUND="$NOTFOUND, flex"
	fi

	# If any aren't found, we need to tell the user
	if [ "$NOTFOUND" != "" ]; then
		# Replace the ", " with a \n to make it go to a new line
		NOTFOUND=$(echo "$NOTFOUND" | sed "s/, /\n/g")
		# Make sure we log it correctly. We don't want color in the log
		if [ "$SILENT" -eq 0 ]; then
			LogOutput "The following dependencies were not found: $TEXTERROR$NOTFOUND$TEXTRESET"
		else
			LogOutput "The following dependencies were not found: $NOTFOUND"
		fi
	fi
}

###############################################################################
# Print dependency check
###############################################################################
DependsResult()
{
	# First check to see if it's in the current path (if not it might be
	# builtin
	if [ "$(which $1)" ]; then
		if [ "$SILENT" -eq 0 ]; then
			LogOutput "$1: $TEXTFOUND"
		else
			LogOutput "$1: [FOUND]"
		fi

		return 0
	fi


	# We don't want to use ExecuteCmd since that'll leave the script on
	# errors
	# Add --help so we at least know it won't go into a loop
	$1 --help &> .tempdep

	# If the command was successful, we're doing well
	if [ $? -eq 0 ]; then
		# Strip the " --help" from the command line
		local COMMAND=$(echo $1 | sed "s/ --help//")
		# Again, don't mess up logging
		if [ "$SILENT" -eq 0 ]; then
			LogOutput "$COMMAND: $TEXTFOUND"
		else
			LogOutput "$COMMAND: [FOUND]"
		fi
		# Remove the temporary output/error file
		QuietExec "rm .tempdep"
		# return success
		return 0
	else
		local COMMAND=$(echo $1 | sed "s/ --help//")
		if [ "$SILENT" -eq 0 ]; then
			LogError "$COMMAND: $TEXTNOTFOUND"
		else
			LogError "$COMMAND: [NOT FOUND]"
		fi
		QuietExec "rm .tempdep"
		return 1
	fi
}

###############################################################################
# Since this is mainly for testing the script, most users don't want to or
# need to build every single compiler available here
# This is a utility since it's used to test the script.
###############################################################################
TestAll()
{
	QuietExec "cd $BASEDIR"
	SetOptions Dreamcast
	BuildDreamcast
	QuietExec "cd $BASEDIR"
#	SetOptions Gamecube
#	All
	BuildLinux DcLinux
	QuietExec "cd $BASEDIR"
#	SetOptions Genesis
#	All
	BuildLinux GcLinux
	QuietExec "cd $BASEDIR"
	SetOptions Ix86
	All
}

Package()
{
	QuietExec "cd $BASEDIR"
	ExecuteCmd "mkdir -p ../buildcross-$BUILDCROSS_VERSION"
	ExecuteCmd "cp -r *.sh COPYING ChangeLog NOTES config.guess options patches/ ../buildcross-$BUILDCROSS_VERSION" "Copying needed files to buildcross-$BUILDCROSS_VERSION"
	BASEDIR=$BASEDIR/../buildcross-$BUILDCROSS_VERSION
	DistClean
	ExecuteCmd "tar cfj ../buildcross-$BUILDCROSS_VERSION.tar.bz2 ../buildcross-$BUILDCROSS_VERSION" "Taring buildcross-$BUILDCROSS_VERSION.tar.bz2"

	exit 0
}
