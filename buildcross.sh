#!/bin/bash
# Version 1.0
# Copyright 2000-2006
#         Harley Laue and others (as noted). All rights reserved.
# 
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions
# are met:
# 1. Redistributions of source code must retain the above copyright
#    notice, this list of conditions and the following disclaimer.
# 2. Redistributions in binary form must reproduce the above copyright
#    notice, this list of conditions and the following disclaimer in the
#    documentation and/or other materials provided with the distribution.
# 3. None of the names of the contributors may be used to endorse or
#    promote products derived from this software without specific prior
#    written permission.
# 
# THIS SOFTWARE IS PROVIDED BY THE AUTHORS AND CONTRIBUTORS ``AS IS'' AND
# ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED.  IN NO EVENT SHALL THE AUTHORS OR CONTRIBUTORS BE LIABLE
# FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
# DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
# OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
# HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
# LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
# OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
# SUCH DAMAGE.


# Most UNIX based systems should have most all of this.
# Depends on bash, sed, mv, cp, ln, pwd, rm, mkdir, grep, and of course gcc
# and binutils


# How to add another target:
# Required:
# Add the options you need to SetOptions (Use one of there as a template)
# Add target name to ParseArgs and have it call SetOptions
# Optional:
# Add your target to Usage


# Even though I'm relatively pleased with this script, there is one limitation
# that I haven't bothered to address which is that the patches must all be in
# one file (the same as the file-version). This could be fixed but I'm unsure
# if there's a big enough need for that. Related to this is that gcc/binutils/
# newlib will have to be removed before it's patched again.

# What the sh compiler is called
SHELF="sh-elf"
# What the arm compiler is called
ARMELF="arm-elf"

# For the BSD people who need it to be gmake
if [ "x$MAKE" == "x" ]; then
	MAKE="make"
fi

# Directory to build from
BASEDIR=`pwd`
# Where to send the output from make and configure
if [ "x$SENDTOWHERE" == "x" ]; then
	# To output to a log
	#SENDTOWHERE="$BASEDIR/output.log"
	# To send to nowhere
	SENDTOWHERE="/dev/null"
fi

# Where to send errors from make and configure
if [ "x$ERRORTOWHERE" == "x" ]; then
	# Errors to a log
	#ERRORTOWHERE="$BASEDIR/error.log"
	# To send errors to nowhere
	ERRORTOWHERE="/dev/null"
fi

# Which thread model gcc should use
if [ "x$THREADS" == "x" ]; then
	# single, posix, or yes for gcc to choose the default threading
	THREADS="yes"
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

# By default show output
SILENT=0
# Gcc version to build
GCCVER="gcc-3.4.6"
# Binutils version to build
BINVER="binutils-2.16.1"
# Newlib version to build
NEWLIBVER="newlib-1.13.0"
# Where the patches are
# Patches should be a single file
PATCHBASEDIR="$BASEDIR/patches"
# Binutils patch
BINPATCH="$BINVER.diff"
# Gcc patch
GCCPATCH="$GCCVER.diff"
# Newlib patch
NEWLIBPATCH="$NEWLIBVER.diff"

# To install to a temporary directory testcompiler
if [ x$TESTING == x ]; then
	TESTING=0
fi

# Some systems may have strange CFLAGS so uncomment below to give your own
if [ "x$BCCFLAGS" == "x" ]; then
	BCCFLAGS=""
fi

# Target choice: "Dreamcast", "Genesis", or "Gamecube"
SYSTEM="Dreamcast"

# Below are options that you may or may not want to change for your system
# of choice
SetOptions()
{
	case $1 in 
		"Dreamcast")
			# Dreamcast options
			# Where kos is located
			if [ "x$KOSLOCATION" == "x" ]; then
				KOSLOCATION="$BASEDIR/kos"
			fi
		
			# Where the Dreamcast patches are
			PATCHDIR="$PATCHBASEDIR/dreamcast"
			# Where to install to
			INSTALL="/usr/local/dc"
			# Binutils options
			BINOPTS="$HOST --disable-nls --with-sysroot=$INSTALL"
			# Gcc base options
			GCCBOPTS="$HOST --with-newlib --disable-nls --without-headers --disable-threads --enable-languages=c"
			# Final Gcc options
			GCCFOPTS="$HOST --with-newlib --disable-nls --enable-symvers=gnu --enable-threads=$THREADS --enable-languages=$LANGUAGES"
			# Newlib options
			NEWLIBOPTS="$HOST"
			# Target
			DCTARG="$SHELF"
			# Used during building of newlib
			TARG1="$DCTARG"
			# The second target for gcc
			TARG2="$ARMELF"
			# End Dreamcast options
			;;
		"Genesis")
			# Genesis options
			# Where the Genesis patches are
			PATCHDIR="$PATCHBASEDIR/genesis"
			# Where to install to
			INSTALL="/usr/local/genesis"
			# Binutils options
			BINOPTS="$HOST --disable-nls --with-sysroot=$INSTALL"
			# Gcc base options
			GCCBOPTS="$HOST --with-newlib --disable-nls --disable-multilib --disable-libssp --without-headers --disable-threads --enable-languages=c"
			# Final Gcc options
			GCCFOPTS="$GCCBOPTS"
			# Newlib options
			NEWLIBOPTS="$HOST"
			# Target
			GENTARG="m68k-genesis-coff"
			# Used during building of newlib
			TARG1="$GENTARG"
			# End Genesis options
			;;
		"Gamecube")
			# Gamecube options
			# Where the Gamecube patches are
			PATCHDIR="$PATCHBASEDIR/gamecube"
			# Where to install to
			INSTALL="/usr/local/gamecube"
			# Gamecube target
			GCTARG="powerpc-gekko-elf"
			# The target
			TARG1="$GCTARG"
			# Binutils options
			BINOPTS="$HOST --disable-nls --with-sysroot=$INSTALL"
			# Gcc base options
			GCCBOPTS="$HOST --with-cpu=750 --with-gcc --with-gnu-ld --with-gnu-as --with-stabs --with-included-gettext --without-headers --disable-nls --disable-shared --disable-threads --disable-multilib --disable-debug --disable-win32-registry --with-newlib --enable-languages=c"
			# Final Gcc options
			GCCFOPTS="$HOST --with-cpu=750 --with-gcc --with-gnu-ld --with-gnu-as --with-stabs --with-included-gettext --without-headers --disable-nls --disable-shared --enable-threads=$THREADS --disable-multilib --disable-debug --disable-win32-registry --with-newlib --enable-__cxa_atexit --enable-c99 --enable-long-long --enable-languages=$LANGUAGES"
			# Newlib options
			NEWLIBOPTS="$HOST"
			# End Gamecube options
			;;
	esac

	# This is here for debugging the script without clobbering the main
	# install
	if [ $TESTING == "1" ]; then
		# For testing uncomment this to put the compiler in a tempdir
		INSTALL="$BASEDIR/testcompiler"
	fi
}

# Set some variables specific for Target 2
SetTarg2()
{
	TARG=$TARG2
	THREADS=""
	TARGET="--target=$TARG2"
	PATCHDIR="$PATCHBASEDIR/$TARG2"
	BINBUILD="$TARG-binbuildelf"
	GCCBUILD="$TARG-gccbuildelf"
	NEWLIBBUILD="$TARG-newlibbuildelf"
	BINOPTS="$BINOPTS"
	GCCBOPTS="--with-arch=armv4 $GCCBOPTS" 
	GCCFOPTS="--with-arch=armv4 $GCCFOPTS"
}

# Create directories to build in
CreateDir()
{
	if [ ! -d $BINBUILD ]; then
		mkdir $BINBUILD
	fi
	if [ ! -d $GCCBUILD ]; then
		mkdir $GCCBUILD
	fi

	if [ ! -d $NEWLIBBUILD ]; then
		mkdir $NEWLIBBUILD
	fi
}

# 1) Try to create directories if needed
# 2) If untar returns true than patch it
# Otherwise it does nothing
UntarPatch()
{
	CreateDir

	if ! Untar $1; then
		Patch $2 $1
		Result "Patching"
	fi
}

# Untar the source if needed
Untar()
{
	# check if the directory for the source exists
	# and that we got to touch that it's untared
	if [ ! -d $1 -o ! -e $1/.untared ]; then
		# Now check if the tar.bz2 file exists
		if [ ! -e $1.tar.bz2 ]; then
			# if it doesn't try for tar.gz
			if [ ! -e $1.tar.gz ]; then
				# if not we don't have the archive so exit
				echo "$1.tar.bz2 or $1.tar.gz not found"
				exec false
			else
				# We have the tar.gz hooray
				echo "Untaring $1.tar.gz"
				tar xfz $1.tar.gz
				# A quick way to tell if we need to untar or not
				touch $1/.untared
				return 1
			fi
		else
			# Well we have the tar.bz2 good job
			echo "Untaring $1.tar.bz2"
			tar xfj $1.tar.bz2
			# A quick way to tell if we need to untar or not
			touch $1/.untared
			return 1
		fi
	fi

	# We didn't need to untar because the directory already existed
	return 0
}

# Try to patch the file
Patch()
{
	# if the patch exists.... You get the idea
	if [ -e $PATCHDIR/$1 ]; then
		echo "Patching $2"
		cd $BASEDIR/$2
		patch -p1 -i $PATCHDIR/$1
		cd $BASEDIR
	fi
}

# Remove the contents of a directory
Remove()
{
	echo "Removing contens of $BASEDIR/$1/*"
	rm -fr $BASEDIR/$1/* $BASEDIR/$1/.*config* $BASEDIR/$1/.*installed*
}

# See if a command like make exited cleanly
Result() 
{
	# I assume the programmers use 0 for clean and other values for not
	if [ $? -eq 0 ]; then
		echo "$0: $1 completed ok"
	else
		echo "$0: $1 failed to complete successfully. Exiting script."
		exec false
	fi
}

# Clean the install directory
CleanInstall()
{
	echo "Cleaning $INSTALL"
	rm -fr $INSTALL/*
}

# Clean the local directories
CleanLocal()
{
	echo "Cleaning $BASEDIR Build files"
	Remove $BINBUILD
	Remove $GCCBUILD
	Remove $NEWLIBBUILD
}

# Check to see if file exists
CheckExists()
{
	if [ -e $1 ]; then
		return 0
	fi

	return 1
}

# Configure Binutils
#
# Since all configures are basically the same this one will
# be the only one documented fully
ConfigureBin()
{
	echo "Configuring binutils"
	# Try to Untar and Patch Binutils if needed
	UntarPatch $BINVER $BINPATCH
	
	# Check if we've already configured. If not, configure
	if ! CheckExists $BINBUILD/.config; then
		# Remove the contents of the build directory
		Remove $BINBUILD
		# Go to the build directory
		cd $BASEDIR/$BINBUILD 

		if [ $SILENT -eq 0 ]; then
			# If it's to be noisy
			../$BINVER/configure $HOST $PREFIX $TARGET $BINOPTS
		else
			# If it's to be silent
			../$BINVER/configure $HOST $PREFIX $TARGET $BINOPTS > $SENDTOWHERE 2> $ERRORTOWHERE
		fi

		# See if configure exited cleanly
		Result "Configuring binutils"
		touch .config
	else
		echo "Already configured"
	fi

	# Go back to the base directory
	cd $BASEDIR
}

# Build binutils
#
# Since all builds are basically the same this one will
# be the only one documented fully
BuildBin()
{
	echo "Building binutils"
	
	# Check if we've installed binutils already
	if ! CheckExists $BINBUILD/.installed; then
		# Change to the build directory
		cd $BASEDIR/$BINBUILD

		if [ $SILENT -eq 0 ]; then
			# If it's noisy build and install
			$MAKE all 
			Result "$MAKE all"
			$MAKE install
		else
			# If it's a quiet build and install, send the output to
			# $SENDTOWHERE and $ERRORTOWHERE
			$MAKE all > $SENDTOWHERE 2> $ERRORTOWHERE
			Result "$MAKE all"
			$MAKE install > $SENDTOWHERE 2> $ERRORTOWHERE
		fi

		# See if the makes exited cleanly
		# This should relatively be ok since install wont work (fully)
		# if make all didn't complete
		Result "Building binutils"
		touch .installed
	else
		echo "Binutils already installed"
	fi

	# Go back to the base directory
	cd $BASEDIR
}

# Configure the base gcc for building newlib
ConfigureBaseGcc()
{
	echo "Configuring initial gcc"
	UntarPatch $GCCVER $GCCPATCH

	# Don't configure base if the final is configured
	if ! CheckExists $GCCBUILD/.finalconfig; then
		if ! CheckExists $GCCBUILD/.config; then
			Remove $GCCBUILD
			cd $BASEDIR/$GCCBUILD

			if [ $SILENT -eq 0 ]; then
				../$GCCVER/configure $HOST $TARGET $PREFIX $GCCBOPTS
			else
				../$GCCVER/configure $HOST $TARGET $PREFIX $GCCBOPTS > $SENDTOWHERE 2> $ERRORTOWHERE
			fi

			Result "Configuring initial gcc"
			touch .config
		else
			echo "Base gcc already configured"
		fi
	else
		echo "Final gcc already configured, not configuring initial again"
	fi

	cd $BASEDIR
}

# Build the base gcc for building newlib
BuildBaseGcc()
{
	echo "Building initial gcc"

	if ! CheckExists $GCCBUILD/.finalconfig; then
		if ! CheckExists $GCCBUILD/.installed; then
			cd $BASEDIR/$GCCBUILD

			if [ $SILENT -eq 0 ]; then
				$MAKE all-gcc 
				Result "$MAKE all-gcc"
				$MAKE install-gcc 
			else
				$MAKE all-gcc > $SENDTOWHERE 2> $ERRORTOWHERE
				Result "$MAKE all-gcc"
				$MAKE install-gcc > $SENDTOWHERE 2> $ERRORTOWHERE
			fi
	
			Result "Building initial gcc"
			touch .installed
		else
			echo "Initial gcc already installed"
		fi
	else
		echo "Final gcc already configured, not building initial agian"
	fi
	
	cd $BASEDIR
}

# Configure newlib
ConfigureNewlib()
{
	echo "Configuring Newlib"
	UntarPatch $NEWLIBVER $NEWLIBPATCH

	if ! CheckExists $NEWLIBBUILD/.config; then
		Remove $NEWLIBBUILD
		cd $BASEDIR/$NEWLIBBUILD

		if [ $SILENT -eq 0 ]; then
			../$NEWLIBVER/configure $HOST $TARGET $PREFIX $NEWLIBOPTS
		else
			../$NEWLIBVER/configure $HOST $TARGET $PREFIX $NEWLIBOPTS > $SENDTOWHERE 2> $ERRORTOWHERE
		fi

		Result "Configuring Newlib"
		touch .config
	else
		echo "Newlib already configured"
	fi

	cd $BASEDIR
}

# Build and install newlib
BuildNewlib()
{
	echo "Building Newlib"
	if ! CheckExists $NEWLIBBUILD/.installed; then
		cd $BASEDIR/$NEWLIBBUILD

		if [ $SILENT -eq 0 ]; then
			$MAKE
			Result "$MAKE"
			$MAKE install
		else
			$MAKE > $SENDTOWHERE 2> $ERRORTOWHERE
			Result "$MAKE"
			$MAKE install > $SENDTOWHERE 2> $ERRORTOWHERE
		fi

		Result "Building Newlib"
		touch .installed
	else
		echo "Newlib already installed"
	fi

	cd $BASEDIR

	if [[ $TARG == $DCTARG && $THREADS == "posix" ]]; then
		# This was taken from Jim Ursetto's makefile script to set up
		# some KOS stuff
		#
		# Only needed for the dreamcast/kos which is what DCTARG was
		# created for
		#
		# I couldn't find any kind of license for this so below may
		# not be covered under the license at the beginning of this
		# file.
		cp $KOSLOCATION/include/pthread.h $INSTALL/$DCTARG/include # KOS pthread.h is modified
		cp $KOSLOCATION/include/sys/_pthread.h $INSTALL/$DCTARG/include/sys # to define _POSIX_THREADS
		cp $KOSLOCATION/include/sys/sched.h $INSTALL/$DCTARG/include/sys # pthreads to kthreads mapping
		ln -nsf $KOSLOCATION/include/kos $INSTALL/$DCTARG/include # so KOS includes are available as kos/file.h
		ln -nsf $KOSLOCATION/kernel/arch/dreamcast/include/arch $INSTALL/$DCTARG/include # kos/thread.h requires arch/arch.h
		ln -nsf $KOSLOCATION/kernel/arch/dreamcast/include/dc $INSTALL/$DCTARG/include # arch/arch.h requires dc/video.h
	fi
}

# Configure the final gcc for you to use
ConfigureFinalGcc()
{
	echo "Configuring final gcc"
	UntarPatch $GCCVER $GCCPATCH

	if ! CheckExists $GCCBUILD/.finalconfig; then
		# I don't like seeing "(reconfigured)" from gcc
		Remove $GCCBUILD
	
		cd $BASEDIR/$GCCBUILD

		if [ $SILENT -eq 0 ]; then
			../$GCCVER/configure $HOST $TARGET $PREFIX $GCCFOPTS
		else
			../$GCCVER/configure $HOST $TARGET $PREFIX $GCCFOPTS > $SENDTOWHERE 2> $ERRORTOWHERE
		fi

		Result "Configuring final gcc"
		touch .finalconfig
	else
		echo "Already configured"
	fi

	cd $BASEDIR
}

# Build the final gcc for you to use
BuildFinalGcc()
{
	echo "Building final gcc"
	
	if ! CheckExists $GCCBUILD/.finalinstalled; then
		cd $BASEDIR/$GCCBUILD

		if [ $SILENT -eq 0 ]; then
			$MAKE all 
			Result "$MAKE all"
			$MAKE install
		else
			$MAKE all > $SENDTOWHERE 2> $ERRORTOWHERE
			Result "$MAKE all"
			$MAKE install > $SENDTOWHERE 2> $ERRORTOWHERE
		fi

		Result "Building final gcc"
		touch .finalinstalled
	else
		echo "Final gcc already installed"
	fi

	cd $BASEDIR
}

# Do it all in a relatively sane manor ;)
All()
{
	echo "Making complete compiler"
	ConfigureBin
	BuildBin
	ConfigureBaseGcc
	BuildBaseGcc
	ConfigureNewlib
	BuildNewlib
	ConfigureFinalGcc
	BuildFinalGcc
}

# Build Dreamcast compiler
BuildDreamcast()
{
	All
	SetTarg2
	All
}

# Build Kos for Dreamcast
BuildKos()
{
	echo "Building kos"
	cd $KOSLOCATION

	cp doc/environ.sh.sample environ.sh

	# Change KOS_BASE to point to where our kos is located
	# I do this by finding the line in the file with grep
	# Then seding the quotes to have a \ in front
	KOSBASELINE=$(grep "^export KOS_BASE\=" environ.sh | sed s/\"/\\\\\"/g)
	# After that I replace each / with a \/ so sed does't get confused
	KOSBASELINE=$(echo "$KOSBASELINE" | sed s/\\\//\\\\\\//g)
	# KOSLOC has the location of kos formatted for sed to read
	KOSLOC=`echo $KOSLOCATION | sed s/\\\//\\\\\\\\\\\//g`
	# Then I replace the old line with the  new one
	sed "s/$KOSBASELINE/export KOS_BASE=\"$KOSLOC\"/" environ.sh > temp
	# Then move the output from that back to envorin.sh
	mv temp environ.sh

	# Same as above for DC_ARM_BASE, but we use where the compiler is
	# installed instead
	ARMBASELINE=$(grep "^export DC_ARM_BASE\=" environ.sh | sed s/\"/\\\\\"/g)
	ARMBASELINE=$(echo "$ARMBASELINE" | sed s/\\\//\\\\\\//g)
	COMPLOC=`echo $INSTALL | sed s/\\\//\\\\\\\\\\\//g`
	sed "s/$ARMBASELINE/export DC_ARM_BASE=\"$COMPLOC\"/" environ.sh > temp 
	mv temp environ.sh
	
	# Same as above for DC_ARM_BASE, but we use where the compiler is
	# installed instead
	ARMPREFIXLINE=$(grep "^export DC_ARM_PREFIX\=" environ.sh | sed s/\"/\\\\\"/g)
	ARMPREFIXLINE=$(echo "$ARMPREFIXLINE" | sed s/\\\//\\\\\\//g)
	sed "s/$ARMPREFIXLINE/export DC_ARM_PREFIX=\"$ARMELF\"/" environ.sh > temp
	mv temp environ.sh

	
	# Same as above but for KOS_CC_BASE
	KOSCCBASELINE=$(grep "^export KOS_CC_BASE\=" environ.sh | sed s/\"/\\\\\"/g)
	KOSCCBASELINE=$(echo $KOSCCBASELINE | sed s/\\\//\\\\\\//g)
	sed "s/$KOSCCBASELINE/export KOS_CC_BASE=\"$COMPLOC\"/g" environ.sh > temp
	mv temp environ.sh

	# Change the standard dc to our prefix
	KOSCCPREFIXLINE=$(grep "^export KOS_CC_PREFIX=" environ.sh | sed s/\"/\\\\\"/g)
	KOSCCPREFIXLINE=$(echo $KOSCCPREFIXLINE | sed s/\\\//\\\\\\//g)
	sed "s/$KOSCCPREFIXLINE/export KOS_CC_PREFIX=\"$SHELF\"/g" environ.sh > temp
	mv temp environ.sh

	# Change the PATH expansion line
	KOSPATHLINE=$(grep "^export PATH=" environ.sh | sed s/\"/\\\\\"/g)
	KOSPATHLINE=$(echo $KOSPATHLINE | sed s/\\\//\\\\\\//g)
	# The sample uses ${KOS_CC_BASE}/bin:/usr/local/dc/bin which means on a standard
	# install it's going to be the same
	sed "s/$KOSPATHLINE/export PATH=\"\${PATH}:\${KOS_CC_BASE}\/bin\"/" environ.sh > temp
	mv temp environ.sh

	# Change the MAKE variable to match the one here
	KOSMAKELINE=$(grep "^export KOS_MAKE=" environ.sh | sed s/\"/\\\\\"/g)
	KOSMAKELINE=$(echo $KOSMAKELINE  | sed s/\\\//\\\\\\//g)
	sed "s/$KOSMAKELINE/export KOS_MAKE=\"$MAKE\"/" environ.sh > temp
	mv temp environ.sh

	# Set environ.sh variables to use
	source environ.sh
	# make kos
	$MAKE clean
	$MAKE
}

# Print out some examples
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
	echo "$0 -cb -bb -c -cig -big -c -cn -bn -c -cfg -bfg -c -t2 -cb -bb -c -cig -big -c -cn -bn -c -cfg -bfg -c"
	echo
	echo "Same as above but clean after each arch is built"
	echo "$0 -all -c -t2 -all -c"
	echo
	echo "This is assuming binutils and the base gcc has been built"
	echo "$0 -cn -bn -cfg -bfg -c"
	echo
	echo "Just clean out the install directory and rebuild"
	echo "$0 -ci -all"
	echo
	echo "Setable variables:"
	echo "KOSLOCATION	For setting where \"kos\" is if not in current directory"
	echo "SENDTOWHERE	For setting where to send output (use absolute path names)"
	echo "ERRORTOWHERE	Same as above but for errors"
	echo "TESTING		Setting it equal to 1 to install compiler to ./testcompiler"
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
	echo "Send output from script to a log file and send any errors to another"
	echo "SENDTOWHERE=\`pwd\`/output.log ERRORTOWHERE=\`pwd\`/error.log $0 -s -all"
	echo "Same as above (remember there's more than one way to do things)"
	echo "$0 -all > output.log 2> error.log"
	echo "Send errors to a log and output to /dev/null"
	echo "ERRORTOWHERE=\`pwd\`/error.log $0 -s -all"
	echo
	echo "Make Dreamcast compiler and put it in a test directory"
	echo "TESTING=1 $0 -dc"
	echo
	echo "Make Dreamcast compiler with cross-compiler and put it test directory"
	echo "TESTING=1 HOSTPRE=sh4-linux-uclibc $0 -dc"
}

# Print the usage for this script
Usage()
{
	echo "$0 usage:"
	echo "	These options must come first"
	echo "	dreamcast Build Gcc for Sega Dreamcast (default)"
	echo "	genesis Build Gcc for Sega Genesis"
	echo "	gamecube Build Gcc for Nintendo Gamecube"
	echo
	echo "	The following will be executed in order from left to right"
	echo "	-ci Clean $INSTALL"
	echo "	-c Clean $BASEDIR build files"
	echo "	-clean Clean all"
	echo
	echo "	-all Configure and build all in correct order"
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
	echo "	(For Dreamcast)"
	echo "	-t2 Set target to two so you can call above for this target"
	echo "	-dc Same ase $0 -all -t2 -all"
	echo "	-k Setup and build kos (Be sure KOSLOCATION is set)"
	echo
	echo "	-s Build silently (needs /dev/null on system, and"
	echo "	   should be called before all that you want silent"
	echo "	   or change $SENDTOWHERE in this script)"
	echo
	echo "	-e Show some examples and setable variables"
}

# This will sort through all arguments and return 0 if it's found and 1 if not
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
			echo "Cleaning all"
			CleanInstall
			CleanLocal
			return 0
			;;
		"-all")
			All
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
		"-t2")
			SetTarg2
			return 0
			;;
		"-dc")
			BuildDreamcast
			return 0
			;;
		"-k")
			BuildKos
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
		"dreamcast")
			SetOptions Dreamcast
			Setup
			return 0
			;;
		"genesis")
			SetOptions Genesis
			Setup
			return 0
			;;
		"gamecube")
			SetOptions Gamecube
			Setup
			return 0
			;;
	esac

	# Command wasn't in above so return 1	
	return 1
}

Setup()
{
	# Which target to use
	TARG="$TARG1"
	# The target for configure
	TARGET="--target=$TARG"
	# The prefix to install for configure
	PREFIX="--prefix=$INSTALL"

	BINBUILD="$TARG-binbuildelf"
	GCCBUILD="$TARG-gccbuildelf"
	NEWLIBBUILD="$TARG-newlibbuildelf"
	
	# If the install directory doesn't exist make it
	if [ ! -d $INSTALL ]; then
		mkdir $INSTALL
	fi

	export PATH=$INSTALL/bin:$PATH
}

main()
{
	# Set up some things the user wont ever need to
	# Default to $SYSTEM options
	SetOptions $SYSTEM
	# Setup directories
	Setup 
	
	# Check if there aren't any arguments
	if [ $# -le 0 ]; then
		# No arguments so print usage and quit
		Usage
		exit
	fi

	# Go through each argument that was given	
	for i in $*; do
		if ! ParseArgs $i; then
			echo "Ignoring unsupported argument \"$i\"";
		fi
		SetOptions $TARG
	done
}

# Just call main and be done with it
main $@

