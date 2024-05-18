###############################################################################
# Copyright 2000-2012
#         Harley Laue (losinggeneration@gmail.com) and others (as noted).
#         All rights reserved.
###############################################################################
# Bash's echo requires -e while dash, zsh, and /bin/echo don't seem to.
# So we'll override it and play it safe if there's no /bin/echo
# Dash's builtin echo doesn't have a -e command, so we remove it. On systems
# that use Bash and don't have /bin/echo it's going to be pretty ugly. In that
# case it'd be best for the user to use -s with buildcross to avoid this issue
###############################################################################
check_echo()
{
	# check if echo supports -e
	if [ "$(echo -e)" = "-e" ]; then
		# if not, see if /bin/echo is there, it might
		if [ -x /bin/echo ]; then
			ECHO="/bin/echo"
		else
			ECHO="echo"
		fi
	else
		ECHO="echo"
	fi

	# if we don't have -e, remove colors to play it safe
	if [ "$($ECHO -e)" = "-e" ]; then
		RemoveColorize
	else
		Colorize
	fi
}

buildcross_echo()
{
	if [ "$TEXTPREFIX" ]; then
		$ECHO $*
	else
		# this may be a bit too much overhead. Perhaps if it's colorized we
		# should just check before sending -e here...
		for i in $*; do
			[ "$i" != "-e" ] && local ECHO_OPTS="$ECHO_OPTS $i"
		done
		$ECHO $ECHO_OPTS
	fi
}

###############################################################################
# Used for checking things in the code. Used with silent most the time so it's
# easy to see debug messages.
###############################################################################
Debug()
{
	buildcross_echo -e "${TEXTPREFIX}debug:: $TEXTDEBUG$*$TEXTRESET"
}

###############################################################################
# To shorten code, ExecuteCmd will redirect output if needed and execute
# Result after executing the command
# Takes the form of ExecuteCmd "Commands to execute" "Message to display"
# "Message to display" can be left off to display the command instead of the
# message in Result
# NOTE:
#	This can't handle redirection of commands like:
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

	local PATH=$INSTALL/bin:$PATH
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
	local PATH=$INSTALL/bin:$PATH
	if [ "$SILENT" -eq 0 ]; then
		$*
	else
		$* >> $SENDTOWHERE 2>> $ERRORTOWHERE
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
	buildcross_echo -e "$TEXTPREFIX## $TEXTTITLE$*$TEXTRESET"
	[ "$SILENT" -ne 0 ] && buildcross_echo "## $*" >> $SENDTOWHERE
}

###############################################################################
# Logs output if needed or just echos it to screen
###############################################################################
LogOutput()
{
	if [ "$SILENT" -eq 0 ]; then
		buildcross_echo -e "$TEXTPREFIX:: $TEXTOUTPUT$*$TEXTRESET"
	else
		buildcross_echo ":: $*" >> $SENDTOWHERE
	fi
}

###############################################################################
# Logs errors if needed or just echos it to screen
###############################################################################
LogError()
{
	buildcross_echo -e "$TEXTPREFIX!! $TEXTERROR$*$TEXTRESET"
	[ "$SILENT" -ne 0 ] && buildcross_echo "!! $*" >> $ERRORTOWHERE
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
	CheckSystem
	[ ! -d "$BINBUILD" ] && QuietExec mkdir -p "$BINBUILD"
	[ ! -d "$GCCBUILD" ] && QuietExec mkdir -p "$GCCBUILD"
	[ ! -d "$NEWLIBBUILD" ] && QuietExec mkdir -p "$NEWLIBBUILD"
	[ "$TARG" = "avr" -a ! -d "$AVRLIBCBUILD" ] && QuietExec mkdir -p "$AVRLIBCBUILD"
	[ ! -d "$GDBBUILD" ] && QuietExec mkdir -p "$GDBBUILD"
}

###############################################################################
# 1) Try to create directories if needed
# 2) If untar returns true than patch it
# Otherwise it does nothing
# $1 is the source name
# $2 is the source version
# $* is the patches (Gcc, Binutils, Newlib, Kos, Kos Ports)
###############################################################################
UntarPatch()
{
	CheckSystem
	CreateDir

	Untar $1 $2 $3

	# We send all parameters because the first is $1 and the rest
	# are the patches, the format we want.
	Patch $*
}

###############################################################################
# Untar the source if needed
###############################################################################
Untar()
{
	CheckSystem
	local name="$1"
	local lver="$2"

	local nameVer=$name-$lver
	local dirVer=$nameVer
	[ $name = "nuttx" ] && dirVer=nuttx-$nameVer
	[ $name = "nuttx-apps" ] && dirVer=$name-nuttx-$lver

	[ -d "$BUILDDIR/$SYSTEM/$dirVer" -a -e "$BUILDDIR/$SYSTEM/$dirVer/.untared-$lver" ] && return

	# Make sure to it's downloaded
	Download $name $lver

	# Now check if the tar file exists
	if CheckExists "$DOWNLOADDIR/${nameVer}.tar.gz"; then
		# We have the tar.gz hooray
		ExecuteCmd "tar xfz $DOWNLOADDIR/${nameVer}.tar.gz -C $BUILDDIR/$SYSTEM" "Untaring ${nameVer}.tar.gz"
	elif CheckExists "$DOWNLOADDIR/${nameVer}.tar.bz2"; then
		# Well we have the tar.bz2 good job
		ExecuteCmd "tar xfj $DOWNLOADDIR/${nameVer}.tar.bz2 -C $BUILDDIR/$SYSTEM" "Untaring ${nameVer}.tar.bz2"
	elif CheckExists "$DOWNLOADDIR/${nameVer}.tar.xz"; then
		# We have the tar.xz
		ExecuteCmd "tar xfJ $DOWNLOADDIR/${nameVer}.tar.xz -C $BUILDDIR/$SYSTEM" "Untaring ${nameVer}.tar.xz"
	else
		LogFatal "Cannot untar $DOWNLOADDIR/${nameVer}.tar.* Make sure $DOWNLOADDIR/.$nameVer-downloaded doesn't exist or the file might be corrupt. If you do get this message tell me how, because it seems like it shouldn't ever come up."
	fi

	# A quick way to tell if we need to untar or not
	QuietExec "touch $BUILDDIR/$SYSTEM/$dirVer/.untared-$lver"
}

GetKernelBase() {
	local x=$(echo $KERNEL | sed "s/.*-\([0-9].[0-9]\).*/\1/")
	local major=$(echo $x | sed "s/\([0-9]\).*/\1/")
	local minor=$(echo $x | sed "s/$major\.\(.*\)/\1/")
	if [ $major -eq 3 -a $minor -gt 0 ]; then
		echo "3.x"
	else
		echo "$x"
	fi
}

###############################################################################
# Download the file
###############################################################################
Download()
{
	CheckSystem
	case $1 in
		"binutils")
			if ! CheckExists $DOWNLOADDIR/.$BINUTILS-downloaded || ! CheckExists $DOWNLOADDIR/$BINUTILS.tar.bz2; then
				ExecuteCmd "wget -O $DOWNLOADDIR/$BINUTILS.tar.bz2 -c https://ftpmirror.gnu.org/gnu/binutils/$BINUTILS.tar.bz2"
				QuietExec "touch $DOWNLOADDIR/.$BINUTILS-downloaded"
			fi
			;;
		"gcc")
			if ! CheckExists $DOWNLOADDIR/.$GCC-downloaded || ! CheckExists $DOWNLOADDIR/$GCC.tar.gz; then
				ExecuteCmd "wget -O $DOWNLOADDIR/$GCC.tar.gz -c https://ftpmirror.gnu.org/gnu/gcc/$GCC/$GCC.tar.gz"
				QuietExec "touch $DOWNLOADDIR/.$GCC-downloaded"
			fi
			;;
		"newlib")
			if ! CheckExists $DOWNLOADDIR/.$NEWLIB-downloaded || ! CheckExists $DOWNLOADDIR/$NEWLIB.tar.gz; then
				ExecuteCmd "wget -O $DOWNLOADDIR/$NEWLIB.tar.gz -c https://sourceware.org/pub/newlib/$NEWLIB.tar.gz"
				QuietExec "touch $DOWNLOADDIR/.$NEWLIB-downloaded"
			fi
			;;
		"uClibc")
			if ! CheckExists $DOWNLOADDIR/.$UCLIBC-downloaded || ! CheckExists $DOWNLOADDIR/$UCLIBC.tar.bz2; then
				if [ $(echo $UCLIBC | grep snapshot) ]; then
					ExecuteCmd "wget -O $DOWNLOADDIR/$UCLIBC.tar.bz2 -c http://uclibc.org/downloads/snapshots/$UCLIBC.tar.bz2"
				elif [ $(echo $UCLIBC | grep "\." ) ]; then
					ExecuteCmd "wget -O $DOWNLOADDIR/$UCLIBC.tar.bz2 -c http://uclibc.org/downloads/$UCLIBC.tar.bz2"
				else
					QuietExec "cd $BUILDDIR/$SYSTEM"
					ExecuteCmd "svn co svn://uclibc.org/trunk/uClibc"
					QuietExec "cd .."
				fi
				QuietExec "touch $DOWNLOADDIR/.$UCLIBC-downloaded"
			fi
			;;
		"glibc")
			if ! CheckExists $DOWNLOADDIR/.$GLIBC-downloaded || ! CheckExists $DOWNLOADDIR/$GLIBC.tar.bz2; then
				ExecuteCmd "wget -O $DOWNLOADDIR/$GLIBC.tar.bz2 -c https://ftpmirror.gnu.org/gnu/glibc/$GLIBC.tar.bz2"
				QuietExec "touch $DOWNLOADDIR/.$GLIBC-downloaded"
			fi
			;;
		"avr-libc")
			if ! CheckExists $DOWNLOADDIR/.$AVRLIBC-downloaded || ! CheckExists $DOWNLOADDIR/$AVRLIBC.tar.bz2; then
				ExecuteCmd "wget -O $DOWNLOADDIR/$AVRLIBC.tar.bz2 -c http://savannah.nongnu.org/download/avr-libc/$AVRLIBC.tar.bz2"
				QuietExec "touch $DOWNLOADDIR/.$AVRLIBC-downloaded"
			fi
			;;
		"$KERNELNAME")
			if ! CheckExists $DOWNLOADDIR/.$KERNEL-downloaded || ! CheckExists $DOWNLOADDIR/$KERNEL.tar.xz; then
				if [ $(echo $KERNEL | grep libc) ]; then
					ExecuteCmd "wget -O $DOWNLOADDIR/$KERNEL.tar.xz -c http://ep09.pld-linux.org/~mmazur/linux-libc-headers/$KERNEL.tar.xz"
				else
					ExecuteCmd "wget -O $DOWNLOADDIR/$KERNEL.tar.xz -c http://www.kernel.org/pub/linux/kernel/v$(GetKernelBase)/$KERNEL.tar.xz"
				fi
				QuietExec "touch $DOWNLOADDIR/.$KERNEL-downloaded"
			fi
			;;
		"kos")
			if ! CheckExists $KOSLOCATION/.kos-downloaded || ! test -d $KOSLOCATION; then
				QuietExec "cd $KOSLOCATION/.."
				ExecuteCmd "git clone git://git.code.sf.net/p/cadcdev/kallistios kos"
				QuietExec "touch $KOSLOCATION/.kos-downloaded"
			fi
			if ! CheckExists $KOSLOCATION/../kos-ports/.kos-ports-downloaded || ! test -d $KOSLOCATION/../kos-ports; then
				QuietExec "cd $KOSLOCATION/.."
				ExecuteCmd "git clone --recursive git://git.code.sf.net/p/cadcdev/kos-ports"
				QuietExec "touch $KOSLOCATION/../kos-ports/.kos-ports-downloaded"
			fi
			QuietExec "cd $BASEDIR"
			;;
		"nuttx")
			if ! CheckExists $DOWNLOADDIR/.$NUTTX-downloaded || ! CheckExists $DOWNLOADDIR/$NUTTX.tar.gz; then
				ExecuteCmd "wget -O $DOWNLOADDIR/$NUTTX.tar.gz -c https://github.com/apache/nuttx/archive/refs/tags/$NUTTX.tar.gz"
				QuietExec "touch $DOWNLOADDIR/.$NUTTX-downloaded"
			fi
			;;
		"nuttx-apps")
			if ! CheckExists $DOWNLOADDIR/.$NUTTXAPPS-downloaded || ! CheckExists $DOWNLOADDIR/$NUTTXAPPS.tar.gz; then
				ExecuteCmd "wget -O $DOWNLOADDIR/$NUTTXAPPS.tar.gz -c https://github.com/apache/nuttx-apps/archive/refs/tags/$NUTTX.tar.gz"
				QuietExec "touch $DOWNLOADDIR/.$NUTTXAPPS-downloaded"
			fi
			;;
		"gdb")
			if ! CheckExists $DOWNLOADDIR/.$GDB-downloaded || ! CheckExists $DOWNLOADDIR/$GDB.tar.gz; then
				ExecuteCmd "wget -O $DOWNLOADDIR/$GDB.tar.gz -c https://ftpmirror.gnu.org/gnu/gdb/$GDB.tar.gz"
				QuietExec "touch $DOWNLOADDIR/.$GDB-downloaded"
			fi
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
	CheckSystem
    local LOC=$BUILDDIR/$SYSTEM/$1-$2

	if [ $1 = "kos" ]; then
		LOC=$KOSLOCATION
	elif [ $1 = "kos-ports" ]; then
		LOC=$KOSLOCATION/../kos-ports
    elif [ $1 = "nuttx" ]; then
		LOC=$BUILDDIR/$SYSTEM/$1-nuttx-$2
    elif [ $1 = "nuttx-apps" ]; then
		LOC=$BUILDDIR/$SYSTEM/$1-nuttx-$2
	fi

	# We need to get past the name/version so shift the params two or three
	shift 2

	[ ! "$PLEVEL" ] && PLEVEL=1

	if ! CheckExists $LOC/.patched; then
		QuietExec "cd $LOC"
		# Go through all parameters passed here which is
		# $(ls patches/sys/namever-*)
		for i in $*; do
			# Only patch if the "if" includes a *.patch or a *.diff
			if [ "$(echo $i | grep -i '\.patch' | grep -v DISABLED)" -o \
					"$(echo $i | grep -i '\.diff' | grep -v DISABLED)" ]; then
				ExecuteCmd "patch -p$PLEVEL -i $i"
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
	if [ -d "$1" ]; then
		LogOutput "Removing contents of $1/* $1/.*config* $1/.*installed*"
		ExecuteCmd "rm -fr $1/* $1/.*config* $1/.*installed*" "Removing $1"
	fi
}

###############################################################################
# Remove the contents of a directory, but leave that if it's been built or not
###############################################################################
CleaningRemove()
{
	CheckSystem
	if [ -d "$1" ]; then
		LogTitle "Removing contents of $1/*"
		ExecuteCmd "rm -fr $1/*" "Removing contents of $1/*"
	fi
}

###############################################################################
# Clean the install directory
###############################################################################
CleanInstall()
{
	CheckSystem
	if [ -d "$INSTALL" ]; then
		LogTitle "Cleaning $INSTALL"
		ExecuteCmd "rm -fr $INSTALL/*" "Cleaning $INSTALL"
	fi
}

###############################################################################
# Clean the local directories
###############################################################################
CleanLocal()
{
	CheckSystem
	LogTitle "Cleaning $BUILDDIR/$SYSTEM Build files"
	Remove $BINBUILD
	Remove $GCCBUILD
	Remove $NEWLIBBUILD
	[ "$UCLIBCDIR" ] && Remove $UCLIBCDIR
	[ "$GLIBCDIR" ] && Remove $GLIBCDIR
}

###############################################################################
# Checks to make sure a system has been selected
###############################################################################
CheckSystem()
{
	[ ! "$SYSTEM" ] && LogFatal "You must select a system!"
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
	# Exists, return 0
	[ -e $1 ] && return 0
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
	ExecuteCmd "rm -fr $DOWNLOADDIR"
	ExecuteCmd "rm -fr $BUILDDIR"
}

###############################################################################
# Check dependencies
###############################################################################
CheckDeps()
{
#	if test ! "$(./config.guess | grep -i 'linux|darwin')"; then
#		LogFatal "Sorry, Checking for dependencies is only known to work in Linux and OS X... for now"
#	fi

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

	if ! DependsResult "xz"; then
		NOTFOUND="$NOTFOUND, xz"
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

	if ! DependsResult "git"; then
		NOTFOUND="$NOTFOUND, git"
	fi
	if ! DependsResult "flex"; then
		NOTFOUND="$NOTFOUND, flex"
	fi


	# If any aren't found, we need to tell the user
	if [ "$NOTFOUND" != "" ]; then
		# Replace the ", " with a \n to make it go to a new line
		NOTFOUND=$(echo "$NOTFOUND" | sed "s/, /\\\n/g")
		# Make sure we log it correctly. We don't want color in the log
		if [ "$SILENT" -eq 0 ]; then
			LogOutput "The following dependencies were not found: $TEXTERROR$NOTFOUND$TEXTRESET"
		else
			LogOutput "The following dependencies were not found: $NOTFOUND"
		fi
	else
		DependsCLibraryResult "gmp.h"
		DependsCLibraryResult "mpfr.h"
		DependsCLibraryResult "mpc.h"
	fi
}

###############################################################################
# Print dependency check
###############################################################################
DependsResult()
{
	# First check to see if it's in the current path (if not it might be
	# builtin
	if [ "$(command -v $1)" ]; then
		if [ "$SILENT" -eq 0 ]; then
			LogOutput "$1: $TEXTFOUND"
		else
			LogOutput "$1: [FOUND]"
		fi

		return 0
	fi

	if [ "$(uname -s)" = "Linux" ]; then
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
	else
		# We don't try as hard if it's not Linux...
		if [ "$SILENT" -eq 0 ]; then
			LogError "$1: $TEXTNOTFOUND"
		else
			LogError "$1: [NOT FOUND]"
		fi
		return 1
	fi
}


###############################################################################
# Print dependency check for a C library
###############################################################################
DependsCLibraryResult() {
	# NetBSD should likely use the pkgsrc include path
	[ "$(uname -s)" = "NetBSD" ] && local DEPCFLAGS="-I/usr/pkg/include"

	# I'd actually have preferred to use this style:
	# gcc -pipe -xc -c -o /dev/null <(echo "#include <$1>") &>/dev/null
	# Unfortunately, I don't think this is as portable as what I have below.
	cat << EOF | gcc -pipe -xc -c $DEPCFLAGS -o /dev/null - 2> /dev/null
		#include <$1>
EOF

	if [ $? -eq 0 ]; then
		# don't mess up logging
		if [ "$SILENT" -eq 0 ]; then
			LogOutput "$1: $TEXTFOUND"
		else
			LogOutput "$1: [FOUND]"
		fi
	else
		if [ "$SILENT" -eq 0 ]; then
			LogError "$1: $TEXTNOTFOUND"
		else
			LogError "$1: [NOT FOUND]"
		fi
	fi
}

###############################################################################
# Since this is mainly for testing the script, most users don't want to or
# need to build every single compiler available here
# This is a utility since it's used to test the script.
###############################################################################
TestAll()
{
	USEUCLIBC=yes
	QuietExec "cd $BASEDIR"
	SetOptions Gamecube
	All
	BuildLinux DcLinux
	QuietExec "cd $BASEDIR"
	BuildLinux Didj
	SetOptions Genesis
	All
	BuildLinux GcLinux
	QuietExec "cd $BASEDIR"
	SetOptions Ix86
	All
	QuietExec "cd $BASEDIR"
	SetOptions Gba
	All
	SetOptions Saturn
	All
	SetOptions Avr
	SinglePass
	QuietExec "cd $BASEDIR"
	SetOptions Dreamcast
	BuildDreamcast
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
