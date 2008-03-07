###############################################################################
# Copyright 2000-2006
#         Harley Laue (losinggeneration@yahoo.com) and others (as noted).
#         All rights reserved.
###############################################################################
#!/bin/bash
###############################################################################
# To shorten code, ExecuteCmd will redirect output if needed
###############################################################################
ExecuteCmd()
{
	if [ $SILENT -eq 0 ]; then
		$*
	else
		$* >> $SENDTOWHERE 2>> $ERRORTOWHERE
	fi
}

###############################################################################
# Logs title output if needed and always prints the title to the screen
###############################################################################
LogTitle()
{
	echo $*
	if [ $SILENT -ne 0 ]; then
		echo $* >> $SENDTOWHERE
	fi
}

###############################################################################
# Logs output if needed or just echos it to screen
###############################################################################
LogOutput()
{
	if [ $SILENT -eq 0 ]; then
		echo $*
	else
		echo $* >> $SENDTOWHERE
	fi
}

###############################################################################
# Logs errors if needed or just echos it to screen
###############################################################################
LogError()
{
	echo $*
	if [ $SILENT -ne 0 ]; then
		echo $* 2>> $ERRORTOWHERE
	fi
}

###############################################################################
# Create directories to build in
###############################################################################
CreateDir()
{
	if [ ! -d $BINBUILD ]; then
		mkdir -p $BINBUILD
	fi

	if [ ! -d $GCCBUILD ]; then
		mkdir -p $GCCBUILD
	fi

	if [ ! -d $NEWLIBBUILD ]; then
		mkdir -p $NEWLIBBUILD
	fi
}

###############################################################################
# 1) Try to create directories if needed
# 2) If untar returns true than patch it
# Otherwise it does nothing
# $1 is the source directory name
# $2-$* is the patches (Gcc, Binutils, Newlib, kos, kos-ports)
###############################################################################
UntarPatch()
{
	CreateDir

	# check if the directory for the source exists
	# and that we got to touch that it's untared
	if [ ! -d $TARG/$1 -o ! -e $TARG/$1/.untared ]; then
		Untar $1
		# Result is here because Untar might have 1 recursive call
		Result "Untaring"
		# A quick way to tell if we need to untar or not
		touch $TARG/$1/.untared
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
	# if not we don't have the archive so
	# download it
	if ! Download $1; then
		LogError "Error downloading file and file not found. Exiting now."
		exec false
	fi

	# What type we have to output correct extention
	local EXT=""

	# Now check if the tar.bz2 file exists
	if ! CheckExists $1.tar.bz2; then
		# if it doesn't try for tar.gz
		if CheckExists $1.tar.gz; then
			# We have the tar.gz hooray
			LogOutput "Untaring $1.tar.gz"
			ExecuteCmd tar xfz $1.tar.gz -C $TARG
			EXT=".tar.gz"
		fi
	else
		# Well we have the tar.bz2 good job
		LogOutput "Untaring $1.tar.bz2"
		ExecuteCmd tar xfj $1.tar.bz2 -C $TARG
		EXT=".tar.bz2"
	fi

	Result "Untared $1.$EXT"
}

###############################################################################
# Download the file
###############################################################################
Download()
{
	# Simple way to log wget messages without a bunch of ifs
	if [ $SILENT -eq 1 ]; then
		WGETOUT="-a $SENDTOWHERE"
	fi

	case $1 in
		"$BINVER")
			if ! CheckExists .$BINVER-downloaded; then
				wget -c $WGETOUT ftp://ftp.gnu.org/gnu/binutils/$BINVER.tar.bz2

				touch .$BINVER-downloaded
			fi
			;;
		"$GCCVER")
			if ! CheckExists .$GCCVER-downloaded; then
				wget -c $WGETOUT ftp://ftp.gnu.org/gnu/gcc/$GCCVER/$GCCVER.tar.bz2

				touch .$GCCVER-downloaded
			fi
			;;
		"$NEWLIBVER")
			if ! CheckExists .$NEWLIBVER-downloaded; then
				wget -c $WGETOUT ftp://sources.redhat.com/pub/newlib/$NEWLIBVER.tar.gz

				touch .$NEWLIBVER-downloaded
			fi
			;;
		"$UCLIBCVER")
			if ! CheckExists .$UCLIBCVER-downloaded; then
				wget -c $WGETOUT http://uclibc.org/downloads/$UCLIBCVER.tar.bz2

				touch .$UCLIBCVER-downloaded
			fi
			;;
		"$KERNELVER")
			if ! CheckExists .$KERNELVER-downloaded; then
				wget -c $WGETOUT http://ep09.pld-linux.org/~mmazur/linux-libc-headers/linux-libc-headers-2.6.12.0.tar.bz2
				
				touch .$KERNELVER-downloaded
			fi
			;;
		"kos")
			if ! CheckExists $TARG/.kos-downloaded; then
				cd $KOSLOCATION/..
				ExecuteCmd svn co https://svn.sourceforge.net/svnroot/cadcdev/kos
				touch .kos-downloaded
			fi
			if ! CheckExists $TARG/.kos-ports-downloaded ; then
				cd $KOSLOCATION/..
				ExecuteCmd svn co https://svn.sourceforge.net/svnroot/cadcdev/kos-ports
				touch .kos-ports-downloaded
			fi
			cd $BASEDIR
			;;
	esac
	# Print the result and exit if failed
	Result "Downoad of $1"

	return 0;
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
			# Only patch if the if does not include disabled or broken
			# This looks strange at first, but if grep doesn't include the
			# word, it returns nothing, thus x`grep ...` == x if the words
			# aren't there.
			if [[ x`echo $i | grep -i disabled` == "x" && x`echo $i | grep -i broken` == "x" ]]; then
				ExecuteCmd patch -p1 -i $i
				Result "Patching $i"
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
	rm -fr $BASEDIR/$1/* $BASEDIR/$1/.*config* $BASEDIR/$1/.*installed*
}

###############################################################################
# Remove the contents of a directory, but leave that if it's been built or not
###############################################################################
CleaningRemove()
{
	LogTitle "Removing contents of $BASEDIR/$1/*"
	rm -fr $BASEDIR/$1/* 
}

###############################################################################
# See if a command like make exited cleanly
###############################################################################
Result() 
{
	# I assume the programmers use 0 for success and other values for not
	if [ $? -eq 0 ]; then
		LogOutput "$0: $1 completed ok" 
	else
		LogError "$0: $1 failed to complete successfully. Exiting script."
		exec false
	fi
}

###############################################################################
# Clean the install directory
###############################################################################
CleanInstall()
{
	LogTitle "Cleaning $INSTALL"
	rm -fr $INSTALL/*
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

	if [ x$TARG == x$DCLTARG ]; then
		rm -fr $UCLIBCDIR
		rm -fr $UCLIBCHDIR
	fi

}

###############################################################################
# Check to see if file exists
###############################################################################
CheckExists()
{
	if [ -e $1 ]; then
		return 0
	fi

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
	ExecuteCmd rm -fr .linux-* .binutils-* .gcc-* .uClibc-* *.bz2 *.gz
	SetOptions Dreamcast
	ExecuteCmd rm -fr $TARG
	SetOptions Gamecube
	ExecuteCmd rm -fr $TARG
	SetOptions DcLinux
	ExecuteCmd rm -fr $TARG
	SetOptions Genesis
	ExecuteCmd rm -fr $TARG
	SetOptions GcLinux
	ExecuteCmd rm -fr $TARG
	SetOptions Ix86
	ExecuteCmd rm -fr $TARG
}

