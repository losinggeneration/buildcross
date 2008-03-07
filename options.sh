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
if [ "x$MAKE" == "x" ]; then
	MAKE="make"
fi

# Where to send the output from make and configure
if [ "x$SENDTOWHERE" == "x" ]; then
	# To output to a log
	#SENDTOWHERE="$BASEDIR/output.log"
	# To send to nowhere
	SENDTOWHERE="/dev/null"
else
	rm -f $SENDTOWHERE
	touch $SENDTOWHERE
fi

# Where to send errors from make and configure
if [ "x$ERRORTOWHERE" == "x" ]; then
	# Errors to a log
	#ERRORTOWHERE="$BASEDIR/error.log"
	# To send errors to nowhere
	ERRORTOWHERE="/dev/null"
else
	rm -f $ERRORTOWHERE
	touch $SENDTOWHERE
fi

# Which thread model gcc should use
if [ "x$THREADS" == "x" ]; then
	# single, posix, or yes for gcc to choose the default threading
	THREADS="posix"
fi

# Some custom CFLAGS to use
if [ "x$BCCFLAGS" != "x" ]; then
	export CFLAGS=$BCCFLAGS
fi

# Which languages gcc should build
if [ "x$LANGUAGES" == "x" ]; then
	# c, c++ are sure things, java, ada, objc
	LANGUAGES="c,c++"
fi

# For cross-compiling... It can sure be a bitch sometimes
if [ "x$HOSTPRE" != "x" ]; then
	# Apparently gcc has some issues with setting build to host
	# I got this basic idea and the sed from crosstool-0.38
	BUILD="--build=$(echo $(./config.guess) | sed s/-/-build_/)"
	HOST="$BUILD --host=$HOSTPRE"
else
	HOST=""
fi

# We only need a single pass for the arm compiler for the Dreamcast
if [ "x$TWOPASS" == "x" ]; then
	TWOPASS=0
fi
###############################################################################
# An abstracted SetOptions which all the main options are set here and in the
# options/configfile. The configfile is where the user editable options are.
###############################################################################
SetOptions()
{
	# Load tho options, but we only care about $TARG right now...
	source options/$1.cfg
	
	# This is here for debugging the script without clobbering the main
	# install
	if [ "x$TESTING" != "x" ]; then
		INSTALL="$TESTING"
	fi

	# Because INSTALL could be changed now, we can overwrite the verible
	# values with the correct ones.
	source options/$1.cfg

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
	echo "$0 usage:"
	echo "	These options must come first"
	echo "	dreamcast Build Gcc for Sega Dreamcast (default)"
	echo "	dclinux Build a Dreamcast Linux compiler"
	echo "	genesis Build Gcc for Sega Genesis"
	echo "	gamecube Build Gcc for Nintendo Gamecube"
	echo "	gclinux Build a GameCub Linux compiler"
	echo "	ix86 Build Gcc for i686"
	echo
	echo "	The following will be executed in order from left to right"
	echo "	-ci Clean $INSTALL"
	echo "	-c Clean $BASEDIR build files"
	echo "	-clean Clean all"
	echo
	echo "	-all Configure and build all in correct order"
	echo "	-allc Configure and build all in correct order, but clean"
	echo "	      objects and remove source after each is built"
	echo
	echo "	-cb Run configure for binutils"
	echo "	-bb Build and install binutils"
	echo
	echo "	-cig Run configure for initial gcc"
	echo "	-big Build and install initial gcc"
	echo "	-cfg Run configure for final gcc"
	echo "	-bfg Build and install final gcc"
	echo
	echo "	-cn Run configure for Newlib"
	echo "	-bn Build and install Newlib"
	echo
	echo "	-s Build silently (needs /dev/null on system, and"
	echo "	   should be called before all that you want silent"
	echo "	   or change $SENDTOWHERE in this script)"
	echo
	echo "	-e Show some examples and setable variables"
	echo
	echo "	-i Will force make/make install to be rerun"
	echo
	echo "	(For Dreamcast)"
	echo "	dcarm Set target to dcarm so you can call above for this target"
	echo "	-dc Same as $0 -all dcarm -all"
	echo "	-dcc Remove src directory and objects after each is built to"
	echo "	     to save space."
	echo "	-k Setup and build kos (Be sure KOSLOCATION is set)"
	echo "	-dcl Build the Dreamcast Linux compiler"
	echo "	-gcl Build the GameCube Linux compiler"
	echo
	echo "	-distclean Cleans All targets, archives, and dot files"

}

###############################################################################
# Print out some examples
###############################################################################
Examples()
{
	echo "Examples:"
	echo "Clean out all installed files from $INSTALL and any files"
	echo "in the build directories then $MAKE and install all"
	echo "$0 -clean -all"
	echo
	echo "Set where KOS is located for Dreamcast build"
	echo "KOSLOCATION defaults to $BASEDIR/kos"
	echo "KOSLOCATION=\"~/dreamcast/kos\" $0 -dc -k"
	echo 
	echo "Build Dreamcast chain and install it"
	echo "$0 -dc"
	echo
	echo "Same as above but clean after each is compiled (I know it's long)"
	echo "It's only needed if you're pretty short on space"
	echo "$0 -cb -bb -c -cig -big -c -cn -bn -c -cfg -bfg -c dcarm -cb -bb -c -cig -big"
	echo
	echo "Do the same as above but with less typing (or copying)"
	echo "$0 -dcc"
	echo "Not that it's not exactly the same because this will leave if each"
	echo "is configured and installed or not. Run $0 -c to remove these from"
	echo "the build directories."
	echo
	echo "This does the same thing only it builds Arm with newlib and C++"
	echo "$0 -cb -bb -c -cig -big -c -cn -bn -c -cfg -bfg -c dcarm -cb -bb -c -cig -big -c -cn -bn -c -cfg -bfg -c"	
	echo
	echo "Againg but with shorter syntax"
	echo "TWOPASS=1 $0 -dcc"
	echo
	echo "Same as above but clean after each arch is built"
	echo "$0 -all -c dcarm -all -c"
	echo
	echo "More of the same, but cleans and removes source after each is built"
	echo "$0 -allc dcarm -allc"
	echo
	echo "This is assuming binutils and the base gcc has been built"
	echo "$0 -cn -bn -cfg -bfg -c"
	echo
	echo "Just clean out the install directory and rebuild"
	echo "$0 -ci -all"
	echo
	echo "Setable variables:"
	echo "KOSLOCATION	For setting where \"kos\" is if not in current directory"
	echo "TWOPASS		To build the Arm compiler for Dreamcast with newlib and C++"
	echo "		Only affects the -dc option"
	echo "SENDTOWHERE	For setting where to send output (use absolute path names)"
	echo "ERRORTOWHERE	Same as above but for errors"
	echo "TESTING		Setting it equal to where to install compiler to. This also"
	echo "		allows you to override the default /usr/local/target prefix if"
	echo "		you want."
	echo "MAKE		For BSD people to use gmake instead of their make"
	echo "LANGUAGES	c, c++ usually will work but java, ada, objc are also usable"
	echo "THREADS		Which thread model to use, posix, single, or \"\" (blank)"
	echo "BCCFLAGS	To define custom CFLAGS for building defaults to \"\""
	echo "HOSTPRE		This will allow you to try and compile with a cross-compiler."
	echo "		I haven't had much luck with doing this though"
	echo
	echo "Tell where kos is located and install the Dreamcast compiler"
	echo "KOSLOCATION=\`pwd\`/../kos $0 -dc"
	echo
	echo "Build the arm compiler with newlib and C++"
	echo "TWOPASS=1 ./$0 -dc"
	echo
	echo "Send output from script to a log file and send any errors to another"
	echo "SENDTOWHERE=\`pwd\`/output.log ERRORTOWHERE=\`pwd\`/error.log $0 -s -all"
	echo "Same as above (remember there's more than one way to do things)"
	echo "$0 -all > output.log 2> error.log"
	echo "Send errors to a log and output to /dev/null"
	echo "ERRORTOWHERE=\`pwd\`/error.log $0 -s -all"
	echo
	echo "Make Dreamcast compiler and put it in a test directory"
	echo "TESTING=\`pwd\`/testcompiler $0 -dc"
	echo
	echo "Make Dreamcast compiler with cross-compiler and put it test directory"
	echo "TESTING=\`pwd\`/testcompiler HOSTPRE=sh4-linux-uclibc $0 -dc"
	echo
	echo "These should give you a pretty good idea on what you can do."
	echo "There are things I probably haven't even really thought about doing too."
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
			SetOptions Gamecube
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
	esac

	# Command wasn't in above so return 1	
	return 1
}

