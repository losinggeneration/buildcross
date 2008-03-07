###############################################################################
# Copyright 2000-2006
#         Harley Laue (losinggeneration@yahoo.com) and others (as noted).
#         All rights reserved.
###############################################################################
#!/bin/bash
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
# See if a command like make exited cleanly
###############################################################################
Result() 
{
	# I assume the programmers use 0 for success and other values for not
	if [ $? -eq 0 ]; then
		LogOutput "$* completed ok" 
	else
		LogFatal "$* failed to complete successfully. Exiting script."
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
		ExecuteCmd "mkdir -p $BINBUILD"
	fi

	if [ ! -d $GCCBUILD ]; then
		ExecuteCmd "mkdir -p $GCCBUILD"
	fi

	if [ ! -d $NEWLIBBUILD ]; then
		ExecuteCmd "mkdir -p $NEWLIBBUILD"
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
	touch $TARG/$1/.untared
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
				touch .$BINVER-downloaded
			fi
			;;
		"$GCCVER")
			if ! CheckExists .$GCCVER-downloaded || ! CheckExists $GCCVER.tar.bz2; then
				ExecuteCmd "wget -c ftp://ftp.gnu.org/gnu/gcc/$GCCVER/$GCCVER.tar.bz2"
				touch .$GCCVER-downloaded
			fi
			;;
		"$NEWLIBVER")
			if ! CheckExists .$NEWLIBVER-downloaded || ! CheckExists $NEWLIBVER.tar.gz; then
				ExecuteCmd "wget -c ftp://sources.redhat.com/pub/newlib/$NEWLIBVER.tar.gz"
				touch .$NEWLIBVER-downloaded
			fi
			;;
		"$UCLIBCVER")
			if ! CheckExists .$UCLIBCVER-downloaded || ! CheckExists $UCLIBCVER.tar.bz2; then
				ExecuteCmd "wget -c http://uclibc.org/downloads/$UCLIBCVER.tar.bz2"
				touch .$UCLIBCVER-downloaded
			fi
			;;
		"$KERNELVER")
			if ! CheckExists .$KERNELVER-downloaded || ! CheckExists $KERNELVER.tar.bz2; then
				ExecuteCmd "wget -c http://ep09.pld-linux.org/~mmazur/linux-libc-headers/$KERNELVER.tar.bz2"
				touch .$KERNELVER-downloaded
			fi
			;;
		"kos")
			if ! CheckExists $KOSLOCATION/.kos-downloaded || ! -d $KOSLOCATION; then
				cd $KOSLOCATION/..
				ExecuteCmd "svn co https://svn.sourceforge.net/svnroot/cadcdev/kos"
				touch .kos-downloaded
			fi
			if ! CheckExists $KOSLOCATION/.kos-ports-downloaded || ! -d $KOSLOCATION/../kos-ports; then
				cd $KOSLOCATION/..
				ExecuteCmd "svn co https://svn.sourceforge.net/svnroot/cadcdev/kos-ports"
				touch .kos-ports-downloaded
			fi
			cd $BASEDIR
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
		cd $LOC
		# Go through all parameters passed here which is
		# $(ls patches/sys/namever-*)
		for i in $*; do
			# Only patch if the "if" does not include disabled or
			# broken
			#
			# This looks strange at first, but if grep doesn't
			# include the word, it returns nothing, thus
			# 'x`grep ...` == "x"' if the words aren't there.
			if [[ x`echo $i | grep -i disabled` == "x" && x`echo $i | grep -i broken` == "x" ]]; then
				ExecuteCmd "patch -p1 -i $i"
			fi
		done

		touch .patched
		cd $BASEDIR
	fi
}

###############################################################################
# Remove the contents of a directory
###############################################################################
Remove()
{
	LogOutput "Removing contents of $BASEDIR/$1/* $BASEDIR/$1/.*config* $BASEDIR/$1/.*installed*"
	ExecuteCmd "rm -fr $BASEDIR/$1/* $BASEDIR/$1/.*config* $BASEDIR/$1/.*installed*" "Removing $1"
}

###############################################################################
# Remove the contents of a directory, but leave that if it's been built or not
###############################################################################
CleaningRemove()
{
	LogTitle "Removing contents of $BASEDIR/$1/*"
	ExecuteCmd "rm -fr $BASEDIR/$1/*" "Removing contents of $BASEDIR/$1/*"
}

###############################################################################
# Clean the install directory
###############################################################################
CleanInstall()
{
	LogTitle "Cleaning $INSTALL"
	ExecuteCmd "rm -fr $INSTALL/*" "Cleaning $INSTALL"
}

###############################################################################
# Clean the local directories
###############################################################################
CleanLocal()
{
	LogTitle "Cleaning $BASEDIR Build files"
	Remove $BINBUILD
	Remove $GCCBUILD
	Remove $NEWLIBBUILD
	Remove $UCLIBCDIR
	Remove $UCLIBCHDIR
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
	cd $BASEDIR
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
	# If a dependency is not found, it's put in this variable
	local NOTFOUND=""

	if ! DependsResult "sed --help"; then
		NOTFOUND= "sed"
	fi

	if ! DependsResult "mv --help"; then
		# Keep the list when adding a new missing dep
		NOTFOUND="$NOTFOUND, mv"
	fi

	if ! DependsResult "cp --help"; then
		NOTFOUND="$NOTFOUND, cp"
	fi

	if ! DependsResult "ln --help"; then
		NOTFOUND="$NOTFOUND, ln"
	fi

	if ! DependsResult "pwd"; then
		NOTFOUND="$NOTFOUND, pwd"
	fi

	if ! DependsResult "rm --help"; then
		NOTFOUND="$NOTFOUND, rm"
	fi

	if ! DependsResult "mkdir --help"; then
		NOTFOUND="$NOTFOUND, mkdir"
	fi

	if ! DependsResult "grep --help"; then
		NOTFOUND="$NOTFOUND, grep"
	fi

	if ! DependsResult "touch --help"; then
		NOTFOUND="$NOTFOUND, touch"
	fi

	if ! DependsResult "gcc --help"; then
		NOTFOUND="$NOTFOUND, gcc"
	fi

	if ! DependsResult "ar --help"; then
		NOTFOUND="$NOTFOUND, binutils"
	fi

	if ! DependsResult "make --help"; then
		NOTFOUND="$NOTFOUND, make"
	fi

	if ! DependsResult "makeinfo --help"; then
		NOTFOUND="$NOTFOUND, texinfo"
	fi
	
	if ! DependsResult "gzip --help"; then
		NOTFOUND="$NOTFOUND, gzip"
	fi
	
	if ! DependsResult "bunzip2 --help"; then
		NOTFOUND="$NOTFOUND, bunzip2"
	fi

	if ! DependsResult "patch --help"; then
		NOTFOUND="$NOTFOUND, patch"
	fi

	if ! DependsResult "awk --help"; then
		NOTFOUND="$NOTFOUND, awk"
	fi

	if ! DependsResult "diff --help"; then
		NOTFOUND="$NOTFOUND, diff"
	fi

	if ! DependsResult "wget --help"; then
		NOTFOUND="$NOTFOUND, wget"
	fi

	if ! DependsResult "svn --help"; then
		NOTFOUND="$NOTFOUND, svn"
	fi

	if ! DependsResult "flex --help"; then
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
	# We don't want to use ExecuteCmd since that'll leave the script on
	# errors
	$1 > .tempdep 2> .tempdep

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
		rm .tempdep
		# return success
		return 0
	else
		local COMMAND=$(echo $1 | sed "s/ --help//")
		if [ "$SILENT" -eq 0 ]; then
			LogError "$COMMAND: $TEXTNOTFOUND"
		else
			LogError "$COMMAND: [NOT FOUND]"
		fi
		rm .tempdep
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
	cd $BASEDIR
	SetOptions Dreamcast
	BuildDreamcast
	cd $BASEDIR
#	SetOptions Gamecube
#	All
	BuildLinux DcLinux
	cd $BASEDIR
#	SetOptions Genesis
#	All
	BuildLinux GcLinux
	cd $BASEDIR
	SetOptions Ix86
	All
}

