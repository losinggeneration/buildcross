###############################################################################
# Copyright 2000-2006
#         Harley Laue (losinggeneration@yahoo.com) and others (as noted).
#         All rights reserved.
###############################################################################
#!/bin/bash
###############################################################################
# Options you may want to change
# You may also want to go down and look at the INSTALL variable for your target
###############################################################################
#By default show output
SILENT=0
# Target choice: "Dreamcast", "DcLinux", "Genesis", "Gamecube", "GcLinux" or
# "Ix86"
SYSTEM="Dreamcast"
# Directory to build from
BASEDIR=$(pwd)
# Where the patches are
PATCHBASEDIR="$BASEDIR/patches"
###############################################################################
# User changeable variables
###############################################################################
# For the BSD people who need it to be gmake
if [ ! "$MAKE" ]; then
	MAKE="make"
fi

# Where to send the output from make and configure
if [ ! "$SENDTOWHERE" ]; then
	# To output to a log
	#SENDTOWHERE="$BASEDIR/output.log"
	# To send to nowhere
	SENDTOWHERE="/dev/null"
else
	rm -f $SENDTOWHERE
	touch $SENDTOWHERE
fi

# Where to send errors from make and configure
if [ ! "$ERRORTOWHERE" ]; then
	# Errors to a log
	#ERRORTOWHERE="$BASEDIR/error.log"
	# To send errors to nowhere
	ERRORTOWHERE="/dev/null"
else
	rm -f $ERRORTOWHERE
	touch $SENDTOWHERE
fi

# Which thread model gcc should use
if [ ! "$THREADS" ]; then
	# single, posix, or yes for gcc to choose the default threading
	THREADS="posix"
fi

# Some custom CFLAGS to use
if [ "$BCCFLAGS" ]; then
	export CFLAGS=$BCCFLAGS
fi

# Which languages gcc should build
if [ ! "$LANGUAGES" ]; then
	# c, c++ are sure things, java, ada, objc
	LANGUAGES="c,c++"
fi

# For cross-compiling... It can sure be a bitch sometimes
if [ "$HOSTPRE" ]; then
	# Apparently gcc has some issues with setting build to host
	# I got this basic idea and the sed from crosstool-0.38
	BUILD="--build=$(echo $(./config.guess) | sed s/-/-build_/)"
	HOST="$BUILD --host=$HOSTPRE"
else
	HOST=""
fi

# We only need a single pass for the arm compiler for the Dreamcast
if [ ! "$TWOPASS" ]; then
	TWOPASS=0
fi

###############################################################################
# Color definitions
###############################################################################
Colorize()
{
	TEXTPREFIX="\033[0;34;1m"
	TEXTOUTPUT="\033[0;32m"
	TEXTRESET="\033[0m"
	TEXTERROR="\033[0;31;1m"
	TEXTTITLE="\033[0;37;1m"
	TEXTFOUND="\033[0;34m[\033[0;1mFOUND\033[0;34m]\033[0m"
	TEXTNOTFOUND="\033[0;34m[\033[0;31;1mNOT FOUND\033[0;34m]\033[0m"
	TEXTDEBUG="\033[0;36;1m"
}

###############################################################################
# Remove color definitions
###############################################################################
RemoveColorize()
{
	TEXTPREFIX=""
	TEXTOUTPUT=""
	TEXTRESET=""
	TEXTERROR=""
	TEXTTITLE=""
	TEXTFOUND="[FOUND]"
	TEXTNOTFOUND="[NOT FOUND]"
	TEXTDEBUG=""
}

###############################################################################
# An abstracted SetOptions which all the main options are set here and in the
# options/configfile. The configfile is where the user editable options are.
###############################################################################
SetOptions()
{
	# This is here for debugging the script without clobbering the main
	# install
	if [ "$TESTING" ]; then
		INSTALL="$TESTING"
	fi

	# Load the default values per config
	source options/$1.cfg

	# These are potentially unset, so make sure they're set to at least $TARG/
	if [ ! "$NEWLIBBUILD" ]; then
		NEWLIBBUILD=$TARG
	fi
	if [ ! "$UCLIBCDIR" ]; then
		UCLIBCDIR=$TARG
	fi
	if [ ! "$UCLIBCHDIR" ]; then
		UCLIBCHDIR=$TARG
	fi

	# Binutils patches
	BINPATCH=$(ls $PATCHDIR/$BINVER-* 2> /dev/null)
	# Gcc patches
	GCCPATCH=$(ls $PATCHDIR/$GCCVER-* 2> /dev/null)
	# Newlib patches
	NEWLIBPATCH=$(ls $PATCHDIR/$NEWLIBVER-* 2> /dev/null)
	# Kos patches
	KOSPATCH=$(ls $PATCHDIR/kos-* 2> /dev/null)
	# Kos-Ports patches
	KOSPORTSPATCH=$(ls $PATCHDIR/kos-ports-* 2> /dev/null)

	# Now we can setup everything else by the variables defined above
	#################################################################
	# The target for configure
	TARGET="--target=$TARG"
	if [ "$HOSTPRE" ]; then
		HOST="$HOST --program-prefix=$TARG-$1-"
	fi
	# The prefix to install for configure
	PREFIX="--prefix=$INSTALL"
	# Now set the options
	BINOPTS="$TARGET $HOST $PREFIX $BINOPTS"
	GCCBOPTS="$TARGET $HOST $PREFIX $GCCBOPTS"
	NEWLIBOPTS="$TARGET $HOST $PREFIX $NEWLIBOPTS"
	GCCFOPTS="$TARGET $HOST $PREFIX $GCCFOPTS"

	# Set up directory names
	BINBUILD="$TARG/binbuildelf"
	GCCBUILD="$TARG/gccbuildelf"
	NEWLIBBUILD="$TARG/newlibbuildelf"
	
	# If the install directory doesn't exist make it
	if [ ! -d $INSTALL ]; then
		mkdir -p $INSTALL
	fi

	# Make sure our install/bin is in the path before our current path
	export PATH=$INSTALL/bin:$PATH
}

###############################################################################
# Print the usage for this script
###############################################################################
Usage()
{
	LogOutput "$0 usage:"
	LogOutput "	These options must come first"
	LogOutput "	dreamcast Build Gcc for Sega Dreamcast (default)"
	LogOutput "	dclinux Build a Dreamcast Linux compiler"
#	LogOutput "	genesis Build Gcc for Sega Genesis"
#	LogOutput "	gamecube Build Gcc for Nintendo Gamecube"
	LogOutput "	gclinux Build a GameCub Linux compiler"
	LogOutput "	ix86 Build Gcc for i686"
	LogOutput
	LogOutput "	The following will be executed in order from left to right"
	LogOutput "	-ci Clean $INSTALL"
	LogOutput "	-c Clean $BASEDIR build files"
	LogOutput "	-clean Clean all"
	LogOutput "	-checkdeps Check to make sure you have all the tools to"
	LogOutput "		build a tool chain"
	LogOutput "	-nocolor Turn off colored output"
	LogOutput
	LogOutput "	-all Configure and build all in correct order"
	LogOutput "	-allc Configure and build all in correct order, but clean"
	LogOutput "	      objects and remove source after each is built"
	LogOutput
	LogOutput "	-cb Run configure for binutils"
	LogOutput "	-bb Build and install binutils"
	LogOutput
	LogOutput "	-cig Run configure for initial gcc"
	LogOutput "	-big Build and install initial gcc"
	LogOutput "	-cfg Run configure for final gcc"
	LogOutput "	-bfg Build and install final gcc"
	LogOutput
	LogOutput "	-cn Run configure for Newlib"
	LogOutput "	-bn Build and install Newlib"
	LogOutput
	LogOutput "	-s Build silently (needs /dev/null on system, and"
	LogOutput "	   should be called before all that you want silent"
	LogOutput "	   or change $SENDTOWHERE in this script)"
	LogOutput
	LogOutput "	-e Show some examples and setable variables"
	LogOutput
	LogOutput "	-i Will force make/make install to be rerun"
	LogOutput
	LogOutput "	(For Dreamcast)"
	LogOutput "	dcarm Set target to dcarm so you can call above for this target"
	LogOutput "	-dc Same as $0 -all dcarm -all"
	LogOutput "	-dcc Remove src directory and objects after each is built to"
	LogOutput "	     to save space."
	LogOutput "	-k Setup and build kos (Be sure KOSLOCATION is set)"
	LogOutput "	-dcl Build the Dreamcast Linux compiler"
	LogOutput "	-gcl Build the GameCube Linux compiler"
	LogOutput
	LogOutput "	-distclean Cleans All targets, archives, and dot files"

}

###############################################################################
# Print out some examples
###############################################################################
Examples()
{
	LogOutput "Examples:"
	LogOutput "Clean out all installed files from $INSTALL and any files"
	LogOutput "in the build directories then $MAKE and install all"
	LogOutput "$0 -clean -all"
	LogOutput
	LogOutput "Set where KOS is located for Dreamcast build"
	LogOutput "KOSLOCATION defaults to $BASEDIR/kos"
	LogOutput "KOSLOCATION=\"~/dreamcast/kos\" $0 -dc -k"
	LogOutput
	LogOutput "Build Dreamcast chain and install it"
	LogOutput "$0 -dc"
	LogOutput
	LogOutput "Same as above but clean after each is compiled (I know it's long)"
	LogOutput "It's only needed if you're pretty short on space"
	LogOutput "$0 -cb -bb -c -cig -big -c -cn -bn -c -cfg -bfg -c dcarm -cb -bb -c -cig -big"
	LogOutput
	LogOutput "Do the same as above but with less typing (or copying)"
	LogOutput "$0 -dcc"
	LogOutput "Not that it's not exactly the same because this will leave if each"
	LogOutput "is configured and installed or not. Run $0 -c to remove these from"
	LogOutput "the build directories."
	LogOutput
	LogOutput "This does the same thing only it builds Arm with newlib and C++"
	LogOutput "$0 -cb -bb -c -cig -big -c -cn -bn -c -cfg -bfg -c dcarm -cb -bb -c -cig -big -c -cn -bn -c -cfg -bfg -c"	
	LogOutput
	LogOutput "Againg but with shorter syntax"
	LogOutput "TWOPASS=1 $0 -dcc"
	LogOutput
	LogOutput "Same as above but clean after each arch is built"
	LogOutput "$0 -all -c dcarm -all -c"
	LogOutput
	LogOutput "More of the same, but cleans and removes source after each is built"
	LogOutput "$0 -allc dcarm -allc"
	LogOutput
	LogOutput "This is assuming binutils and the base gcc has been built"
	LogOutput "$0 -cn -bn -cfg -bfg -c"
	LogOutput
	LogOutput "Just clean out the install directory and rebuild"
	LogOutput "$0 -ci -all"
	LogOutput
	LogOutput "Setable variables:"
	LogOutput "KOSLOCATION	For setting where \"kos\" is if not in current directory"
	LogOutput "TWOPASS		To build the Arm compiler for Dreamcast with newlib and C++"
	LogOutput "		Only affects the -dc option"
	LogOutput "SENDTOWHERE	For setting where to send output (use absolute path names)"
	LogOutput "ERRORTOWHERE	Same as above but for errors"
	LogOutput "TESTING		Setting it equal to where to install compiler to. This also"
	LogOutput "		allows you to override the default /usr/local/target prefix if"
	LogOutput "		you want."
	LogOutput "MAKE		For BSD people to use gmake instead of their make"
	LogOutput "LANGUAGES	c, c++ usually will work but java, ada, objc are also usable"
	LogOutput "THREADS		Which thread model to use, posix, single, or \"\" (blank)"
	LogOutput "BCCFLAGS	To define custom CFLAGS for building defaults to \"\""
	LogOutput "HOSTPRE		This will allow you to try and compile with a cross-compiler."
	LogOutput "		I haven't had much luck with doing this though"
	LogOutput
	LogOutput "Tell where kos is located and install the Dreamcast compiler"
	LogOutput "KOSLOCATION=\`pwd\`/../kos $0 -dc"
	LogOutput
	LogOutput "Build the arm compiler with newlib and C++"
	LogOutput "TWOPASS=1 ./$0 -dc"
	LogOutput
	LogOutput "Send output from script to a log file and send any errors to another"
	LogOutput "SENDTOWHERE=\`pwd\`/output.log ERRORTOWHERE=\`pwd\`/error.log $0 -s -all"
	LogOutput "Same as above (remember there's more than one way to do things)"
	LogOutput "$0 -all > output.log 2> error.log"
	LogOutput "Send errors to a log and output to /dev/null"
	LogOutput "ERRORTOWHERE=\`pwd\`/error.log $0 -s -all"
	LogOutput
	LogOutput "Make Dreamcast compiler and put it in a test directory"
	LogOutput "TESTING=\`pwd\`/testcompiler $0 -dc"
	LogOutput
	LogOutput "Make Dreamcast compiler with cross-compiler and put it test directory"
	LogOutput "TESTING=\`pwd\`/testcompiler HOSTPRE=sh4-linux-uclibc $0 -dc"
	LogOutput
	LogOutput "These should give you a pretty good idea on what you can do."
	LogOutput "There are things I probably haven't even really thought about doing too."
}

###############################################################################
# This will sort through all arguments and return 0 if it's found and 1 if not
###############################################################################
ParseArgs()
{
	# If the argument is found it executes the action the return true
	case $1 in
		"-ci")
			CleanInstall
			return 0
			;;
		"-c")
			CleanLocal
			return 0
			;;
		"-clean")
			LogTitle "Cleaning all"
			CleanInstall
			CleanLocal
			return 0
			;;
		"-checkdeps")
			CheckDeps
			return 0
			;;
		"-nocolor")
			RemoveColorize
			return 0
			;;
		"-all")
			All
			return 0
			;;
		"-allc")
			CleanningAll
			return 0
			;;
		"-cb")
			ConfigureBin
			return 0
			;;
		"-bb")
			BuildBin
			return 0
			;; 
		"-cig")
			ConfigureBaseGcc
			return 0
			;;
		"-big")
			BuildBaseGcc
			return 0
			;;
		"-cfg")
			ConfigureFinalGcc
			return 0
			;;
		"-bfg")
			BuildFinalGcc
			return 0
			;;
		"-cn")
			ConfigureNewlib
			return 0
			;;
		"-bn") 
			BuildNewlib
			return 0
			;;
		"-cu")
			ConfigureuClibc
			return 0
			;;
		"-bu")
			BuilduClibc
			return 0
			;;
		"dcarm")
			SetOptions DcArm
			return 0
			;;
		"-dc")
			BuildDreamcast
			return 0
			;;
		"-dcc")
			BuildCleaningDreamcast
			return 0
			;;
		"-k")
			BuildKos
			return 0
			;;
		"-dcl")
			BuildLinux DcLinux
			return 0
			;;
		"-gcl")
			BuildLinux GcLinux
			return 0
			;;
		"-s")
			SILENT=1
			return 0
			;;
		"-e")
			# Print examples and quit
			Examples
			exit
			;;
		"-i")
			rm $TARG-*/.*installed*
			return 0
			;;
		"dreamcast")
			SetOptions Dreamcast
			return 0
			;;
		"dclinux")
			SetOptions DcLinux
			return 0
			;;
		"genesis")
			SetOptions Genesis
			return 0
			;;
		"gamecube")
			LogFatel "Gamecube disabled"
#			SetOptions Gamecube
			return 0
			;;
		"gclinux")
			SetOptions GcLinux
			return 0
			;;
		"ix86")
			SetOptions Ix86
			return 0
			;;
		"-distclean")
			DistClean
			return 0
			;;
		"-testall")
			TestAll
			return 0
			;;
	esac

	# Command wasn't in above so return 1	
	return 1
}

