###############################################################################
# Copyright 2000-2012
#         Harley Laue (losinggeneration@gmail.com) and others (as noted).
#         All rights reserved.
###############################################################################
# Options you may want to change
# You may also want to go down and look at the INSTALL variable for your target
###############################################################################
#By default show output
SILENT=0
# Target choice: "Dreamcast", "DcLinux", "Genesis", "Gamecube", "GcLinux" or
# "Ix86"
#SYSTEM="Dreamcast"
# Directory to build from
BASEDIR="$(pwd)"
# Where the patches are
PATCHBASEDIR="$BASEDIR/patches"
# Where the builds are
BUILDDIR="$BASEDIR/builds"
# Where the downloads are
DOWNLOADDIR="$BASEDIR/downloads"
###############################################################################
# User changeable variables
###############################################################################
# For the BSD people who need it to be gmake
[ ! "$MAKE" ] && MAKE="make"

[ ! -d "$BUILDDIR" ] && QuietExec "mkdir -p $BUILDDIR"
[ ! -d "$DOWNLOADDIR" ] && QuietExec "mkdir -p $DOWNLOADDIR"

# Where to send the output from make and configure
if [ ! "$SENDTOWHERE" ]; then
	# To output to a log
	#SENDTOWHERE="$BASEDIR/output.log"
	# To send to nowhere
	SENDTOWHERE="/dev/null"
else
	QuietExec "rm -f $SENDTOWHERE"
	QuietExec "touch $SENDTOWHERE"
fi

# Where to send errors from make and configure
if [ ! "$ERRORTOWHERE" ]; then
	# Errors to a log
	#ERRORTOWHERE="$BASEDIR/error.log"
	# To send errors to nowhere
	ERRORTOWHERE="/dev/null"
else
	QuietExec "rm -f $ERRORTOWHERE"
	QuietExec "touch $SENDTOWHERE"
fi

# Which thread model gcc should use
# single, posix, or yes for gcc to choose the default threading
[ ! "$THREADS" ] && THREADS="posix"

# Some custom CFLAGS to use
[ "$BCCFLAGS" ] && export CFLAGS="$BCCFLAGS"

# Which languages gcc should build
# c, c++ are sure things, java, ada, objc
[ ! "$LANGUAGES" ] && LANGUAGES="c,c++"

# For cross-compiling... It can sure be a bitch sometimes
if [ "$HOSTPRE" ]; then
	# Apparently gcc has some issues with setting build to host
	# I got this basic idea and the sed from crosstool-0.38
	BUILD="--build=$(echo $(./config.guess) | sed s/-/-build_/)"
	HOST="$BUILD --host=$HOSTPRE"
else
	BUILD="--build=$(echo $(./config.guess) | sed s/-/-build_/)"
	HOST=""
fi

# We only need a single pass for the arm compiler for the Dreamcast
[ ! "$TWOPASS" ] && TWOPASS=0

# Default to uClibc
USEUCLIBC=yes

# This can cause problems if set, so unset it for this script
unset C_INCLUDE_PATH

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
	TEXTCOMPLETED="\033[0;34m[\033[0;1mOK\033[0;34m]\033[0m"
	TEXTFAILED="\033[0;34m[\033[0;31;1mFAILED\033[0;34m]\033[0m"
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
	TEXTCOMPLETED="[OK]"
	TEXTFAILED="[FAILED]"
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
	[ "$TESTING" ] && INSTALL="$TESTING"

	# Load the default values per config
	local filename="`echo $1.cfg | tr "[:upper:]" "[:lower:]"`"
	. ./options/$filename

	# KOS should have a sane default location rather than the build directory
	if [ "$USEKOS" -a ! "$KOSLOCATION" ]; then
		KOSLOCATION="$INSTALL/kos"
	fi

	# These are potentially unset, so make sure they're set to at least $SYSTEM/
	[ ! "$NEWLIBBUILD" ] && NEWLIBBUILD="$BUILDDIR/$SYSTEM"
	[ ! "$UCLIBCDIR" ] && UCLIBCDIR="$BUILDDIR/$SYSTEM"
	[ ! "$GLIBCHDIR" ] && GLIBCHDIR="$BUILDDIR/$SYSTEM"
	[ ! "$GDBBUILD" ] && GDBBUILD="$BUILDDIR/$SYSTEM"

	# These are patches common to to all compilers. For instance, when a patch
	# is required to build any compiler:
	# E.G. texinfo >= 5.1 & binutils <= 2.23.1 won't build
	COMMONPATCHES="$BASEDIR/patches/common"
	BINUTILS="binutils-$BINVER"
	GCC="gcc-$GCCVER"
	NEWLIB="newlib-$NEWLIBVER"
	AVRLIBC="avr-libc-$AVRLIBCVER"
	GLIBC="glibc-$GLIBCVER"
	UCLIBC="uClibc-$UCLIBCVER"
	KERNEL="$KERNELNAME-$KERNELVER"
	NUTTX="nuttx-$NUTTXVER"
	NUTTXAPPS="nuttx-apps-$NUTTXVER"
	GDB="gdb-$GDBVER"

	# Binutils patches
	BINPATCH="$COMMONPATCHES/$BINUTILS-* $PATCHDIR/$BINUTILS-*"
	# Gcc patches
	GCCPATCH="$COMMONPATCHES/$GCC-* $PATCHDIR/$GCC-*"
	# Newlib patches
	NEWLIBPATCH="$COMMONPATCHES/$NEWLIB-* $PATCHDIR/$NEWLIB-*"
	# Kos patches
	KOSPATCH="$COMMONPATCHES/$kos-* $PATCHDIR/kos-*"
	# Kos-Ports patches
	KOSPORTSPATCH="$COMMONPATCHES/$kos-ports-* $PATCHDIR/kos-ports-*"
	# Glibc patches
	GLIBCPATCH="$COMMONPATCHES/$GLIBC-* $PATCHDIR/$GLIBC-*"
	# uClibc patches
	UCLIBCPATCH="$COMMONPATCHES/$UCLIBC-* $PATCHDIR/$UCLIBC-*"
	AVRLIBCPATCH="$COMMONPATCHES/$AVRLIBC-* $PATCHDIR/$AVRLIBC-*"
	GDBPATCH="$COMMONPATCHES/$GDB-* $PATCHDIR/$GDB-*"

	# Now we can setup everything else by the variables defined above
	#################################################################
	# The target for configure
	TARGET="--target=$TARG"

	# If this is not done, it will name the native compiler gcc/as/etc
	# which will often confuse the system when it can't execute the 
	# system gcc.
	# This is normally only really needed when building a native compiler
	# when using a cross compiler of the same name. Doesn't hurt in any
	# case besides possibly having a longer executable name.
	[ "$HOSTPRE" ] && HOST="$HOST --program-prefix=$TARG-"
	# The prefix to install for configure
	PREFIX="--prefix=$INSTALL"
	# Now set the options
	BINOPTS="$TARGET $HOST $PREFIX $BINOPTS"
	GCCBOPTS="$TARGET $HOST $PREFIX $GCCBOPTS"
	NEWLIBOPTS="$TARGET $HOST $PREFIX $NEWLIBOPTS"
	GCCFOPTS="$TARGET $HOST $PREFIX $GCCFOPTS"
	AVRLIBCOPTS="$TARGET $HOST $PREFIX $AVRLIBCOPTS"
	# Glibc's prefix must be /usr because we use sysroot
	GLIBCHOPTS="$TARGET $HOST $BUILD --prefix=/usr $GLIBCHOPTS"
	GLIBCFOPTS="--host=$TARG $TARGET $BUILD --prefix=/usr $GLIBCFOPTS"

	GDBOPTS="$TARGET $HOST $PREFIX $GDBOPTS"

	# Set up directory names
	BINBUILD="$BUILDDIR/$SYSTEM/binbuildelf"
	GCCBUILD="$BUILDDIR/$SYSTEM/gccbuildelf"
	NEWLIBBUILD="$BUILDDIR/$SYSTEM/newlibbuildelf"
	AVRLIBCBUILD="$BUILDDIR/$SYSTEM/avrlibcbuild"
	NUTTXDIR="$BUILDDIR/$SYSTEM/nuttx-$NUTTX"
	GDBBUILD="$BUILDDIR/$SYSTEM/gdbbuild"

	# If the install directory doesn't exist make it
	[ ! -d "$INSTALL" ] && QuietExec mkdir -p $INSTALL

	# if HOSTPRE and TARG are the same you're bound to hit some program
	# name collisions
	# Make sure our install/bin is in the path before our current path
	[ "$HOSTPRE" != "$TARG" ] && export PATH=$INSTALL/bin:$PATH
}

###############################################################################
# Print the usage for this script
###############################################################################
Usage()
{
	LogOutput "$0 usage:"
	LogOutput "	These options must come first"
	LogOutput "	dreamcast Build Gcc for Sega Dreamcast"
	LogOutput "	dclinux Build a Dreamcast Linux compiler"
	LogOutput "	genesis Build Gcc for Sega Genesis"
	LogOutput "	gamecube Build Gcc for Nintendo Gamecube"
	LogOutput "	gclinux Build a GameCube Linux compiler"
	LogOutput "	ix86 Build Gcc for i686"
	LogOutput "	archlinuxppc Build Gcc for ArchLinuxPPC"
	LogOutput "	saturn Build Gcc for Sega Saturn"
	LogOutput "	gba Build Gcc for Game Boy Advance"
	LogOutput "	avr Build Gcc for the Atmel AVR chips"
	LogOutput
	LogOutput "	The following will be executed in order from left to right"
	LogOutput "	-ci Clean \$INSTALL (typically /usr/local/{dc,dc-linux,gamecube}"
	LogOutput "	-c Clean $BASEDIR build files"
	LogOutput "	-clean Clean all"
	LogOutput "	-checkdeps Check to make sure you have all the tools to"
	LogOutput "		build a tool chain (May only work with GNU versions"
	LogOutput "		of the tools.)"
	LogOutput "	-nocolor Turn off colored output"
	LogOutput
	LogOutput "	-all Configure and build two pass newlib compiler"
	LogOutput "	-allc Configure and build two pass newlib compiler, but clean"
	LogOutput "       objects and remove source after each is built"
	LogOutput "	-single Run a single pass. Equivilant to -cb -bb -cfg -bfg [-ca -ba (AVR only)]"
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
	LogOutput "	-ck Configure/install kernel headers"
	LogOutput
	LogOutput "	-cu Run configure on uClibc"
	LogOutput "	-bu Build and install uClibc"
	LogOutput
	LogOutput "	-ca Run configure on AVR libc"
	LogOutput "	-ba Build and install AVR libc"
	LogOutput
	LogOutput "	-cg Configure Glibc"
	LogOutput "	-c2g Configure Glibc after the initial Gcc is installed"
	LogOutput "	-bg Build and Install initial Glibc after initial Gcc"
	LogOutput "	-b2g Build and install Glibc before final Gcc is built"
	LogOutput
	LogOutput "	-cnx Configure NuttX"
	LogOutput "	-bnx Build NuttX"
	LogOutput
	LogOutput "	-cgdb Configure Gdb"
	LogOutput "	-bgdb Build Gdb"
	LogOutput "	-gdb Configure & Build Gdb"
	LogOutput
	LogOutput "	-s Build silently (needs /dev/null on system, and"
	LogOutput "    should be called before all that you want silent"
	LogOutput "    or change $SENDTOWHERE in this script)"
	LogOutput
	LogOutput "	-i Will remove .install files to have make install to be rerun"
	LogOutput
	LogOutput "	(For Dreamcast)"
	LogOutput "	dcarm Set target to dcarm so you can call above for this target"
	LogOutput "	-dc Same as $0 -all dcarm -all"
	LogOutput "	-dcc Remove src directory and objects after each is built to"
	LogOutput "      to save space."
	LogOutput "	-k Setup and build kos (Be sure KOSLOCATION is set)"
	LogOutput "	-nlk Ues ln instead of cp for kos headers when installing newlib"
	LogOutput "	-gc Same as $0 gamecube -all gcmn10200 -cb -bb gamecube -gc-rules -gc-tools"
	LogOutput "	-gc-rules Installs gamecube related rules from devkitppc"
	LogOutput "	-gc-tools Builds gamecube related tools from devkitppc"
	LogOutput "	-genesis Same as TESTING='/usr/local/m68k' $0 genesis -all z80 -cb -bb"
	LogOutput "	-u Use uClibc instead of Glibc for Linux compilers"
	LogOutput "	-dcl Build the Dreamcast Linux compiler"
	LogOutput "	-gcl Build the GameCube Linux compiler"
	LogOutput "	-bl  Build Linux compiler for selected target"
	LogOutput "	-native Used before -dcl, -gcl, or -bl to build a native"
	LogOutput "         compiler. You must set HOSTPRE to the target name also."
	LogOutput
	LogOutput "	-distclean Cleans All targets, archives, and dot files"
	LogOutput
	LogOutput "	-h|-help This message"
	LogOutput "	-e Show some examples and setable variables"

}

###############################################################################
# Print out some examples
###############################################################################
Examples()
{
	LogOutput "Examples:"
	LogOutput "Clean out all installed files from \$INSTALL and any files"
	LogOutput "in the build directories then make and install all"
	LogOutput "$0 dreamcast -clean -all"
	LogOutput
	LogOutput "Set where KOS is located for Dreamcast build"
	LogOutput "KOSLOCATION defaults to $BASEDIR/kos"
	LogOutput "KOSLOCATION=\"~/dreamcast/kos\" $0 -dc"
	LogOutput
	LogOutput "Build Dreamcast chain and install it"
	LogOutput "$0 -dc"
	LogOutput
	LogOutput "Same as above but clean after each is compiled (I know it's long)"
	LogOutput "It's only needed if you're pretty short on space"
	LogOutput "$0 dreamcast -cb -bb -c -cig -big -c -cn -bn -c -cfg -bfg -c \ "
	LogOutput "dcarm -cb -bb -c -cig -big"
	LogOutput
	LogOutput "Do the same as above but with less typing (or copying)"
	LogOutput "$0 -dcc"
	LogOutput "Not that it's not exactly the same because this will leave if each"
	LogOutput "is configured and installed or not. Run $0 -c to remove these"
	LogOutput "from the build directories."
	LogOutput
	LogOutput "This does the same thing only it builds Arm with newlib and C++"
	LogOutput "$0 dreamcast -cb -bb -c -cig -big -c -cn -bn -c -cfg -bfg -c \ "
	LogOutput "dcarm -cb -bb -c -cig -big -c -cn -bn -c -cfg -bfg -c"
	LogOutput
	LogOutput "Again but with shorter syntax"
	LogOutput "TWOPASS=1 $0 -dcc"
	LogOutput
	LogOutput "Same as above but clean after each arch is built"
	LogOutput "$0 dreamcast -all -c dcarm -all -c"
	LogOutput
	LogOutput "More of the same, but cleans and removes source after each is built"
	LogOutput "$0 dreamcast -allc dcarm -allc"
	LogOutput
	LogOutput "This is assuming binutils and the base gcc has been built"
	LogOutput "$0 dreamcast -cn -bn -cfg -bfg -c"
	LogOutput
	LogOutput "Just clean out the install directory and rebuild"
	LogOutput "$0 dreamcast -ci -all"
	LogOutput
	LogOutput "Setable variables:"
	LogOutput "KOSLOCATION	For setting where \"kos\" is if not in current directory"
	LogOutput "TWOPASS	To build the Arm compiler for Dreamcast with newlib and C++"
	LogOutput "		Only affects the -dc option"
	LogOutput "SENDTOWHERE	For setting where to send output (use absolute path names)"
	LogOutput "ERRORTOWHERE	Same as above but for errors"
	LogOutput "TESTING	Setting it equal to where to install compiler to. This also"
	LogOutput "		allows you to override the default /usr/local/target prefix if"
	LogOutput "		you want."
	LogOutput "MAKE		For BSD people to use gmake instead of their make"
	LogOutput "LANGUAGES	c, c++ usually will work but java, ada, objc are also usable"
	LogOutput "THREADS	Which thread model to use, posix, single, or \"\" (blank)"
	LogOutput "BCCFLAGS	To define custom CFLAGS for building defaults to \"\""
	LogOutput "HOSTPRE	This will allow you to try and compile with a cross-compiler."
	LogOutput "		I had luck with doing this with sh4-linux-uclibc, others are"
	LogOutput "		untested"
	LogOutput "USEUCLIBC	If set, it will use uClibc instead of Glibc for Linux compilers"
	LogOutput
	LogOutput "Tell where kos is located and install the Dreamcast compiler"
	LogOutput "KOSLOCATION=\`pwd\`/../kos $0 -dc"
	LogOutput
	LogOutput "Build the arm compiler with newlib and C++"
	LogOutput "TWOPASS=1 ./$0 -dc"
	LogOutput
	LogOutput "Send output from script to a log file and send any errors to another"
	LogOutput "SENDTOWHERE=\`pwd\`/output.log ERRORTOWHERE=\`pwd\`/error.log  "
	LogOutput "$0 -s -all"
	LogOutput
	LogOutput "Same as above (remember there's more than one way to do things)"
	LogOutput "$0 -all > output.log 2> error.log"
	LogOutput
	LogOutput "Send errors to a log and output to /dev/null"
	LogOutput "ERRORTOWHERE=\`pwd\`/error.log $0 -s -all"
	LogOutput
	LogOutput "Make Dreamcast compiler and put it in a test directory"
	LogOutput "TESTING=\`pwd\`/testcompiler $0 -dc"
	LogOutput
	LogOutput "Make Dreamcast compiler with cross-compiler and put it test directory"
	LogOutput "TESTING=\`pwd\`/testcompiler HOSTPRE=sh4-linux-uclibc $0 -dc"
	LogOutput
	LogOutput "Make a native Dreamcast uClibc Linux compiler"
	LogOutput "HOSTPRE='sh4-linux-uclibc' $0 -u -native -dcl"
	LogOutput
	LogOutput "Same as above, but with the full options on the command line"
	LogOutput "HOSTPRE='sh4-linux-uclibc' $0 -u dclinux -cb -bb -cu -cfg -bfg"
	LogOutput "NOTE: -u MUST be before dclinux, and dclinux MUST be specified"
	LogOutput
	LogOutput "An example to use distcc to build the Dreamcast cross-compiler"
	LogOutput "Make must be set to how many hosts you have, CC is a bit more paranoid here"
	LogOutput "than it may need to be by including gcc's version, and the HOSTS are only"
	LogOutput "defined if not defined globally through a shell variable"
	LogOutput "DISTCC_HOSTS='localhost anotherhost' MAKE='make -j2' \ "
	LogOutput "'CC='distcc powerpc-unknown-linux-gnu-gcc-4.1.2' $0 -dc"
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
		"-single")
			SinglePass
			return 0
			;;
		"-cb")
			Remove $BINBUILD
			ConfigureBin
			return 0
			;;
		"-bb")
			Remove $BINBUILD/.installed
			BuildBin
			return 0
			;; 
		"-cig")
			Remove $GCCBUILD
			ConfigureGcc "Initial"
			return 0
			;;
		"-big")
			Remove $GCCBUILD/.installed-Initial
			BuildGcc "Initial"
			return 0
			;;
		"-cfg")
			Remove $GCCBUILD
			ConfigureGcc "Final"
			return 0
			;;
		"-bfg")
			Remove $GCCBUILD/.installed-Final
			BuildGcc "Final"
			return 0
			;;
		"-cn")
			Remove $NEWLIBBUILD
			ConfigureNewlib
			return 0
			;;
		"-bn")
			Remove $NEWLIBBUILD/.installed
			BuildNewlib
			return 0
			;;
		"-ck")
			ConfigureKernelHeaders
			return 0
			;;
		"-ca")
			Remove "$AVRLIBCBUILD/.configure"
			ConfigureAVRlibc
			return 0
			;;
		"-ba")
			Remove "$AVRLIBCBUILD/.installed"
			BuildAVRlibc
			return 0
			;;
		"-cu")
			ExecuteCmd "rm -f $UCLIBCDIR/.configure"
			ConfigureuClibc
			return 0
			;;
		"-bu")
			Remove $UCLIBCDIR/.installed
			BuilduClibc
			return 0
			;;
		"-cg")
			Remove $GLIBCDIR
			ConfigureGlibc "Headers"
			return 0
			;;
		"-c2g")
			Remove $GLIBCDIR
			ConfigureGlibc "Final"
			return 0
			;;
		"-bg")
			Remove $GLIBCDIR/.installed-Initial
			BuildGlibc "Initial"
			return 0
			;;
		"-b2g")
			Remove $GLIBCDIR/.installed-Final
			BuildGlibc "Final"
			return 0
			;;
		"-cnx")
			ConfigureNuttX
			return 0
			;;
		"-bnx")
			BuildNuttX
			return 0
			;;
		"-cgdb")
			Remove $GDBBUILD
			ConfigureGdb
			return 0
			;;
		"-bgdb")
			Remove $GDBBUILD/.installed
			BuildGdb
			return 0
			;;
		"-gdb")
			ConfigureGdb
			BuildGdb
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
		"-nlk")
			USELN=yes
			return 0
			;;
		"-gc")
			BuildGamecube
			return 0
			;;
		"-gc-rules")
			InstallGamecubeRules
			return 0
			;;
		"-gc-tools")
			InstallGamecubeTools
			return 0
			;;
		"-genesis")
			BuildGenesis
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
		"-bl")
			BuildLinux
			return 0
			;;
		"-u")
			USEUCLIBC=yes
			return 0
			;;
		"-g")
			unset USEUCLIBC
			return 0
			;;
		"-native")
			NATIVECOMPILER=yes
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
		# I'll have three here in case the standard --help is tried
		"-h" | "-help" | "--help")
			Usage
			return 0
			;;
		"-i")
			rm $BUILDDIR/$SYSTEM/*/.*installed*
			return 0
			;;
		"-distclean")
			DistClean
			return 0
			;;
		# For testing purposes, this will run the script on all known
		# targets
		"-testall")
			TestAll
			return 0
			;;
		# A nice way to package the script
		"-package")
			Package
			return 0
			;;
		# Check all remaining parameters for targets
		*)
			# If the option isn't found above, see if it's a configuration
			# We also allow arbitrary capitalization
			if [ -f "`echo options/$1.cfg | tr "[:upper:]" "[:lower:]"`" ]; then
				SetOptions $1
				return 0
			fi
			;;
	esac

	# Command wasn't in above so return 1
	return 1
}

