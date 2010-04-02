#!/bin/bash
###############################################################################
# Copyright 2000-2007
#         Harley Laue (losinggeneration@yahoo.com) and others (as noted).
#         All rights reserved.
###############################################################################
# Configure Binutils
###############################################################################
# Since all configures are basically the same this one will
# be the only one documented fully
###############################################################################
ConfigureBin()
{
	LogTitle "Configuring Binutils"
	# Try to Untar and Patch Binutils if needed
	UntarPatch binutils $BINVER $BINPATCH

	# Check if we've already configured. If not, configure
	if ! CheckExists $BINBUILD/.configure; then
		# Remove the contents of the build directory
		Remove $BINBUILD
		# Go to the build directory
		QuietExec "cd $BASEDIR/$BINBUILD"

		ExecuteCmd "../$BINUTILS/configure $BINOPTS" "Configuring Binutils"
		QuietExec "touch .configure"
	else
		LogTitle "Binutils Already configured"
	fi

	# Go back to the base directory
	cd $BASEDIR
}

###############################################################################
# Build Binutils
###############################################################################
# Since all builds are basically the same this one will
# be the only one documented fully
###############################################################################
BuildBin()
{
	LogTitle "Building Binutils"

	# Check if we've installed binutils already
	if ! CheckExists $BINBUILD/.installed; then
		# Change to the build directory
		QuietExec "cd $BASEDIR/$BINBUILD"

		ExecuteCmd "$MAKE all"

		ExecuteCmd "$MAKE install" "Building Binutils"
		if [ "$SHELF" ]; then
			ExecuteCmd "$MAKE install-bfd" "Install libbfd"
		fi

		QuietExec "touch .installed"
	else
		LogTitle "Binutils already installed"
	fi

	# Go back to the base directory
	QuietExec "cd $BASEDIR"
}

###############################################################################
# Configure Gcc
# $1 values: "Initial" or "Final"
###############################################################################
ConfigureGcc()
{
	LogTitle "Configuring $1 Gcc"
	for langs in $(echo $LANGUAGES | sed "s/,/ /g"); do
		case $langs in
			"c")
				langs="core" ;;
			"fortran")
				langs="g77" ;;
			"c++")
				langs="g++" ;;
		esac

		GccUntar $GCCVER $langs
	done

	Patch gcc $GCCVER $langs $GCCPATCH

	if ! CheckExists $GCCBUILD/.configure-$1; then
		# This will remove all files, but leave hidden ones
		ExecuteCmd "rm -fr $GCCBUILD/*"
		QuietExec "cd $BASEDIR/$GCCBUILD"

		if [ "$1" == "Initial" ]; then
			local OPTS=$GCCBOPTS
		else
			OPTS=$GCCFOPTS
		fi

		ExecuteCmd "../$GCC/configure $OPTS" "Configuring $1 Gcc"
		QuietExec "touch .configure-$1"
	else
		LogTitle "Gcc $1 already configured"
	fi

	cd $BASEDIR
}

###############################################################################
# Build Gcc
# $1 valuse: "Initial" or "Final"
###############################################################################
BuildGcc()
{
	LogTitle "Building $1 Gcc"

	if ! CheckExists $GCCBUILD/.installed-$1; then
		QuietExec "cd $BASEDIR/$GCCBUILD"

		if [ "$1" == "Initial" ]; then
			# Ok, Gcc 4.3 seems to change all-gcc's behavior. It's now split
			# into all-gcc and all-target-libgcc. So now we have to check for
			# newer versions.
			GCCMAJOR="`echo $GCCVER | cut -d. -f1`"
			GCCMINOR="`echo $GCCVER | cut -d. -f2`"

			local GCCBUILD="all-gcc"
			local GCCINSTALL="install-gcc"
			if [ "$GCCMAJOR" = "4" -a "$GCCMINOR" -ge 3 ]; then
				GCCBUILD="$GCCBUILD all-target-libgcc all-libiberty"
				GCCINSTALL="$GCCINSTALL install-target-libgcc install-libiberty"
			fi

			ExecuteCmd "$MAKE $GCCBUILD"
			ExecuteCmd "$MAKE $GCCINSTALL" "Building $1 Gcc"
		else
			ExecuteCmd "$MAKE all"
			ExecuteCmd "$MAKE install" "Building $1 Gcc"
		fi
		QuietExec "touch .installed-$1"
	else
		LogTitle "$1 Gcc already installed"
	fi

	cd $BASEDIR
}

###############################################################################
# Configure Newlib
###############################################################################
ConfigureNewlib()
{
	LogTitle "Configuring Newlib"
	UntarPatch newlib $NEWLIBVER $NEWLIBPATCH

	if ! CheckExists $NEWLIBBUILD/.configure; then
		Remove $NEWLIBBUILD
		QuietExec "cd $BASEDIR/$NEWLIBBUILD"

		ExecuteCmd "../$NEWLIB/configure $NEWLIBOPTS" "Configuring Newlib"
		QuietExec "touch .configure"
	else
		LogTitle "Newlib already configured"
	fi

	QuietExec "cd $BASEDIR"
}

###############################################################################
# Build and install Newlib
###############################################################################
BuildNewlib()
{
	LogTitle "Building Newlib"
	if ! CheckExists $BASEDIR/$NEWLIBBUILD/.installed; then
		QuietExec "cd $BASEDIR/$NEWLIBBUILD"

		ExecuteCmd "$MAKE"
		ExecuteCmd "$MAKE install" "Building Newlib"

		# SHELF is defined in Dreamcast.cfg
		if [ "$SHELF" ]; then
			if [ $THREADS == "posix" -o $THREADS == "yes" ]; then
				# Make sure KOS is downloaded before trying to copy files from
				# it
				QuietExec "mkdir -p $KOSLOCATION"
				Download kos
				###############################################################
				# This was taken from Jim Ursetto's Makefile script to set up
				# some KOS stuff
				###############################################################
				# Only needed for the Dreamcast/kos
				###############################################################
				# I couldn't find any kind of license for this so below may
				# not be covered under the license at the beginning of this
				# file.
				###############################################################
				LogTitle "Symlinking KOS libraries..."
				# KOS pthread.h is modified
				ExecuteCmd "cp $KOSLOCATION/include/pthread.h $INSTALL/$TARG/include"
				# to define _POSIX_THREADS
				ExecuteCmd "cp $KOSLOCATION/include/sys/_pthread.h $INSTALL/$TARG/include/sys"
				# pthreads to kthreads mapping
				ExecuteCmd "cp $KOSLOCATION/include/sys/sched.h $INSTALL/$TARG/include/sys"
				# so KOS includes are available as kos/file.h
				ExecuteCmd "ln -nsf $KOSLOCATION/include/kos $INSTALL/$TARG/include"
				# kos/thread.h requires arch/arch.h
				ExecuteCmd "ln -nsf $KOSLOCATION/kernel/arch/dreamcast/include/arch $INSTALL/$TARG/include"
				# arch/arch.h requires dc/video.h
				ExecuteCmd "ln -nsf $KOSLOCATION/kernel/arch/dreamcast/include/dc $INSTALL/$TARG/include"
			fi
		fi

		QuietExec "touch $BASEDIR/$NEWLIBBUILD/.installed"
	else
		LogTitle "Newlib already installed"
	fi

	QuietExec "cd $BASEDIR"
}

###############################################################################
# Configure AVRlibc
###############################################################################
ConfigureAVRlibc()
{
	LogTitle "Configuring AVRlibc"

	UntarPatch avr-libc $AVRLIBCVER $AVRLIBCPATCH

	if ! CheckExists $AVRLIBCBUILD/.configure; then
		Remove $AVRLIBCBUILD
		QuietExec "cd $BASEDIR/$AVRLIBCBUILD"

		ExecuteCmd "../$AVRLIBC/configure $AVRLIBCOPTS" "Configuring AVRlibc"
		QuietExec "touch .configure"
	else
		LogTitle "AVRlibc already configured"
	fi

	QuietExec "cd $BASEDIR"
}

###############################################################################
# Build and install AVRlibc
###############################################################################
BuildAVRlibc()
{
	LogTitle "Building AVRlibc"

	if ! CheckExists $AVRLIBCBUILD/.installed; then
		QuietExec "cd $BASEDIR/$AVRLIBCBUILD"

		ExecuteCmd "$MAKE"
		ExecuteCmd "$MAKE install" "Installing AVRlibc"
	else
		LogTitle "$1 AVRlibc already installed"
	fi
}

ConfigureKernelHeaders()
{
	# this if statemest probably isn't needed
	if [ "$USEUCLIBC" ]; then
		QuietExec "cd $SYSTEM/$KERNEL"

		if [ $(echo $KERNEL | grep libc) ]; then
			# If it's the old headers, we we'll cd to include
			QuietExec "cd include"

			# Make sure we link to the correct asm for the target
			case $TARG in
				"$DCLTARG" | "$SH2TARG")
					QuietExec "rm -f asm"
					QuietExec "ln -s asm-sh asm"
					;;
				"$GCLTARG")
					QuietExec "rm -f asm"
					QuietExec "ln -s asm-ppc asm"
					;;
				*)
					LogFatal "You shouldn't try building uClibc without a known target"
					;;
			esac
		else
			# isn't this so much nicer?
			ExecuteCmd "make ARCH=$GENERICTARG CROSS_COMPILE=$TARG- INSTALL_HDR_PATH=$SYSROOT/usr headers_install"
		fi
	else
		QuietExec "cd $BASEDIR/$TARG/$KERNEL"
		if [ $(echo $KERNEL | grep libc) ]; then
			ExecuteCmd "cp -r include/linux $HEADERSDIR"
			#ExecuteCmd "cp -r include/asm-generic $HEADERSDIR/asm-generic"
			ExecuteCmd "cp -r include/asm-$GENERICTARG $HEADERSDIR/asm"
		else
			ExecuteCmd "make ARCH=$GENERICTARG CROSS_COMPILE=$TARG- INSTALL_HDR_PATH=$SYSROOT/usr headers_install"
		fi
	fi
}

###############################################################################
# Configure uClibc
###############################################################################
ConfigureuClibc()
{
	LogTitle "Configuring uClibc"
	UntarPatch uClibc $UCLIBCVER $UCLIBCPATCH
	UntarPatch $KERNELNAME $KERNELVER $KERNELPATCH

	if ! CheckExists $UCLIBCDIR/.configure; then
		ConfigureKernelHeaders "uclibc"

		QuietExec "cd $BASEDIR"

		QuietExec "mkdir -p $UCLIBCHDIR/usr/include"
		QuietExec "mkdir -p $UCLIBCHDIR/usr/lib"
		QuietExec "mkdir -p $UCLIBCHDIR/lib"

		QuietExec "cd $BASEDIR/$UCLIBCDIR"

		sed -e "s,KERNELSOURCEDIR,$SYSROOT/usr/include," -e "s,COMPILERPREFIX,$TARG-," -e "s,SHAREDLIBPREFIX,$UCLIBCHDIR," -e "s,RUNDEVPREFIX,$UCLIBCHDIR/usr," $PATCHDIR/$UCLIBC-config > .config

		ExecuteCmd "make V=1 PREFIX=$UCLIBCHDIR DEVEL_PREFIX=/usr/ RUNTIME_PREFIX=$UCLIBCHDIR headers install_headers"
		QuietExec "touch .configure"
	else
		LogTitle "uClibc already configured"
	fi

	QuietExec "cd $BASEDIR"
}

###############################################################################
# Build and install uClibc
###############################################################################
BuilduClibc()
{
	LogTitle "Building uClibc"
	if ! CheckExists $UCLIBCDIR/.installed; then
		QuietExec "cd $BASEDIR/$UCLIBCDIR"

		ExecuteCmd "$MAKE"
		ExecuteCmd "$MAKE install" "Building uClibc"
		# Ok, building went ok, so install the libs and includes
		# to the right prefix
		ExecuteCmd "cp -r $UCLIBCHDIR/usr/include $INSTALL"
		# this command sometimes fails, no big deal...
		cp -r $UCLIBCHDIR/usr/lib/* $INSTALL/lib
		cd $INSTALL/$TARG
		ExecuteCmd "ln -snf ../include sys-include"
		ExecuteCmd "ln -snf ../include include"
		# this can safely fail without consequence
		cp -r lib/* ../lib
		ExecuteCmd "rm -fr lib"
		ExecuteCmd "ln -snf ../lib lib"
		cd -
		QuietExec "touch .installed"
	else
		LogOutput "uClibc already installed"
	fi

	cd $BASEDIR
}

###############################################################################
# Configure Glibc
# $1 values: "Headers" or "Final"
###############################################################################
ConfigureGlibc()
{
	LogTitle "Configuring Glibc $1"
	UntarPatch glibc $GLIBCVER $GLIBCPATCH
	UntarPatch $KERNELNAME $KERNELVER $KERNELPATCH
	QuietExec "mkdir -p $GLIBCDIR"

	if ! CheckExists $GLIBCDIR/.configure-$1; then
		QuietExec "cd $BASEDIR/$GCLIBCDIR"
		if [ "$1" == "Headers" ]; then
			# Prepare the linux headers
			ConfigureKernelHeaders

			# Now get the Glibc headers installed
			QuietExec "cd $BASEDIR/$GLIBCDIR"

			CC=gcc ExecuteCmd "../$GLIBC/configure $GLIBCHOPTS" "Configuring Glibc Headers"
			ExecuteCmd "$MAKE cross-compiling=yes install_root=$SYSROOT install-headers" "Installing Glibc Headers"

			# Taken/adapted from CrossTool
			# Two headers -- stubs.h and features.h -- aren't installed by install-headers,
			# so do them by hand.  We can tolerate an empty stubs.h for the moment.
			# See e.g. http://gcc.gnu.org/ml/gcc/2002-01/msg00900.html
			QuietExec "mkdir -p $HEADERSDIR/gnu"
			QuietExec "touch $HEADERSDIR/gnu/stubs.h"
			QuietExec "cp ../$GLIBC/include/features.h $HEADERSDIR/features.h"
			# End stuff from CrossTool
			# Hmm, bits/stdio_lim.h doesn't seem to be getting installed, simple fix, copy it to the correct location
			# seems $HEADERSDIR/bits may not be created by default, so make sure it's there
			QuietExec "mkdir -p $HEADERSDIR/bits"
			QuietExec "cp bits/stdio_lim.h $HEADERSDIR/bits/stdio_lim.h"

		else
			QuietExec "cd $BASEDIR/$GLIBCDIR"
			# Remove contents that may be in there after initial configure/make"
			QuietExec "rm -fr *"

			# Taken/adapted from CrossTool
			# For glibc 2.3.4 and later we need to set some autoconf cache
			# variables, because nptl/sysdeps/pthread/configure.in does not
			# work when cross-compiling.
			libc_cv_forced_unwind=yes
			libc_cv_c_cleanup=yes
			export libc_cv_forced_unwind libc_cv_c_cleanup

			# Setting the pre-configure options adapted from CrossTool
			BUILD_CC=gcc CC=$TARG-gcc AR=$TARG-ar RANLIB=$TARG-ranlib ExecuteCmd "../$GLIBC/configure $GLIBCFOPTS"

			Result "Configuring Glibc"
		fi
		QuietExec "touch .configure-$1"
	else
		LogTitle "Glibc already configured"
	fi

	QuietExec "cd $BASEDIR"
}

###############################################################################
# Build and install Glibc
# $1 values: "Initial" or "Final" though, anything other than "Initial" works
###############################################################################
BuildGlibc()
{
	LogTitle "Building Glibc $1"
	if ! CheckExists $GLIBCDIR/.installed-$1; then
		QuietExec "cd $BASEDIR/$GLIBCDIR"

		if [ "$1" == "Initial" ]; then
			ExecuteCmd "$MAKE LD=$TARG-ld RANLIB=$TARG-ranlib lib"
			# install-lib-all is defined in patched version of the Makefile only
			ExecuteCmd "$MAKE install_root=$SYSROOT install-lib-all install-headers"

		else
			ExecuteCmd "$MAKE LD=$TARG-ld RANLIB=$TARG-ranlib"
			ExecuteCmd "$MAKE install_root=$SYSROOT install-bin install-rootsbin install-sbin install-data install-others"
		fi

		QuietExec "touch .installed-$1"
	else
		LogOutput "Glibc $1 already installed"
	fi

	cd $BASEDIR
}

###############################################################################
# Build Kos for Dreamcast
###############################################################################
BuildKos()
{
	LogTitle "Building Kos"
	Download kos

	QuietExec "cd $KOSLOCATION"

	#######################################################################
	# This is to setup the environ.sh to what our compiler is
	#######################################################################
	QuietExec "cp doc/environ.sh.sample environ.sh"

	# Change KOS_BASE to point to where our Kos is located
	KOSBASELINE=$(grep -n "^export KOS_BASE\=" environ.sh | cut -f1 -d:)

	# Then I replace the old line with the new one
	sed -e "$KOSBASELINE c export KOS_BASE=\"$KOSLOCATION\"" -i environ.sh
	# Instead of being overly paranoid, we'll just use one Result to make
	# sure we got the environ.sh copied correctly.
	Result "sed -e \"$KOSBASELINE c export KOS_BASE=\"$KOSLOCATION\"\" -i environ.sh"
	LogOutput "Changed KOS_BASE with $KOSLOCATION"

	if [ "$TARG" == "$SHELF" -o "$TARG" == "$ARMELF" ]; then
		# Same as above for DC_ARM_BASE, but we use where the compiler is
		# installed instead
		ARMBASELINE=$(grep -n "^export DC_ARM_BASE\=" environ.sh | cut -f1 -d:)
		sed -e "$ARMBASELINE c export DC_ARM_BASE=\"$INSTALL\"" -i environ.sh
		LogOutput "Changed DC_ARM_BASE with $INSTALL"

		# Same as above for DC_ARM_BASE, but we use where the compiler is
		# installed instead
		ARMPREFIXLINE=$(grep -n "^export DC_ARM_PREFIX\=" environ.sh | cut -f1 -d:)
		sed -e "$ARMPREFIXLINE c export DC_ARM_PREFIX=\"$ARMELF\"" -i environ.sh
		LogOutput "Changed DC_ARM_PREFIX with $ARMELF"

		# Needed because we can't just use $SHELF for the cc prefix anymore
		THISTARG=$SHELF
	else
		# if the arch isn't Dreamcast, it's ia32
		ARCHBASELINE=$(grep -n "^export KOS_ARCH=\"dreamcast\"" environ.sh)
		sed -e "$ARCHBASELINE c export KOS_ARCH=\"ia32\"" -i environ.sh
		LogOutput "Changed KOS_ARCH to $ARCHBASELINE"

		# Comment these two out if its not the dreamcast compiler
		ARMBASELINE=$(grep -n "^export DC_ARM_BASE\=" environ.sh | cut -f1 -d:)
		sed -e "$ARMBASELINE c #export DC_ARM_BASE=" -i environ.sh
		LogOutput "Changed DC_ARM_BASE to $ARMBASELINE"

		ARMPREFIXLINE=$(grep -n "^export DC_ARM_PREFIX\=" environ.sh | cut -f1 -d:)
		sed -e "$ARMPREFIXLINE c #export DC_ARM_PREFIX=" -i environ.sh
		LogOutput "Changed DC_ARM_PREFIX to $ARMPREFIXLINE"

		THISTARG=$TARG
	fi

	# Same as above but for KOS_CC_BASE
	KOSCCBASELINE=$(grep -n '^export KOS_CC_BASE=' environ.sh | cut -f1 -d:)
	sed -e "$KOSCCBASELINE c export KOS_CC_BASE=\"$INSTALL\"" -i environ.sh
	LogOutput "Changed KOS_CC_BASE to $KINSTALL"

	# Change the standard dc to our prefix
	KOSCCPREFIXLINE=$(grep -n "^export KOS_CC_PREFIX=" environ.sh | cut -f1 -d:)
	sed -e "$KOSCCPREFIXLINE c export KOS_CC_PREFIX=\"$THISTARG\"" -i environ.sh
	LogOutput "Changed KOS_CC_PREFIX to $THISTARG"

	# Change the PATH expansion line
	KOSPATHLINE=$(grep -n "^export PATH=" environ.sh | cut -f1 -d:)
	# The sample uses ${KOS_CC_BASE}/bin:/usr/local/dc/bin which means on a standard
	# install it's going to be the same
	sed -e "$KOSPATHLINE c export PATH=\"\${PATH}:\${KOS_CC_BASE}/bin\"" -i environ.sh
	LogOutput "Changed PATH to \${PATH}:\${KOS_CC_BASE}/bin\""

	# Change the MAKE variable to match the one here
	KOSMAKELINE=$(grep -n "^export KOS_MAKE=" environ.sh | cut -f1 -d:)
	sed -e "$KOSMAKELINE c export KOS_MAKE=\"$MAKE\"" -i environ.sh
	LogOutput "Changed KOS_MAKE to $MAKE"
	#######################################################################

	# Set environ.sh variables to use
	source environ.sh

	Patch kos $KOSPATCH
	QuietExec "cd $KOSLOCATION"
	# make kos
	ExecuteCmd "$MAKE clean"
	ExecuteCmd "$MAKE" "Building Kos"

	Patch kos-ports $KOSPORTSPATCH
	# make kos-ports
	QuietExec "cd $KOSLOCATION/../kos-ports"
	ExecuteCmd "$MAKE clean"
	ExecuteCmd "$MAKE" "Building Kos ports"
}

###############################################################################
# Do it all in a relatively sane manor ;)
###############################################################################
All()
{
	LogTitle "Making complete compiler"
	ConfigureBin
	BuildBin
	ConfigureGcc "Initial"
	BuildGcc "Initial"
	ConfigureNewlib
	BuildNewlib
	ConfigureGcc "Final"
	BuildGcc "Final"
}

###############################################################################
# Some compilers really only need a single pass, AVR for example
# TODO: We may want to have an option to compile newlib if desired
###############################################################################
SinglePass()
{
	LogTitle "Making a single pass compiler"
	ConfigureBin
	BuildBin
	ConfigureGcc "Final"
	BuildGcc "Final"

	if [ $TARG = "avr" ]; then
		ConfigureAVRlibc
		BuildAVRlibc
	fi
}

###############################################################################
# Do it all, and keep it cleaned up while you're at it
###############################################################################
CleaningAll()
{
	LogTitle "Making complete compiler"
	ConfigureBin
	BuildBin
	CleaningRemove $BINBUILD
	QuietExec "rm -fr $BASEDIR/$SYSTEM/$BINUTILS"
	ConfigureGcc "Initial"
	BuildGcc "Initial"
	CleaningRemove $GCCBUILD
	QuietExec "rm -fr $BASEDIR/$SYSTEM/$GCC"
	ConfigureNewlib
	BuildNewlib
	CleaningRemove $NEWLIBBUILD
	QuietExec "rm -fr $BASEDIR/$SYSTEM/$NEWLIB"
	ConfigureGcc "Final"
	BuildGcc "Final"
	CleaningRemove $GCCBUILD
	QuietExec "rm -fr $BASEDIR/$SYSTEM/$GCC"
}

###############################################################################
# Build Dreamcast compiler
###############################################################################
BuildDreamcast()
{
	# Make sure we're in the right target
	SetOptions Dreamcast

	All
	SetOptions DcArm

	# The default is to do a single pass without Newlib for target (arm)
	if [ $TWOPASS -eq 1 ]; then
		LogTitle "Making two pass Arm compiler for Dreamcast"
		All
	else
		LogTitle "Making single pass Arm compiler for Dreamcast"
		ConfigureBin
		BuildBin
		ConfigureGcc "Initial"
		BuildGcc "Initial"
	fi

	BuildKos
}

###############################################################################
# Build Dreamcast compiler, and save some space when building
###############################################################################
BuildCleaningDreamcast()
{
	# Make sure we're in the right target
	SetOptions Dreamcast

	CleaningAll
	SetOptions DcArm

	# The default is to do a single pass without Newlib for target 2 (arm)
	if [ $TWOPASS -eq 1 ]; then
		CleaningAll
	else
		ConfigureBin
		BuildBin
		CleaningRemove $BINBUILD
		QuietExec "rm -fr $BASEDIR/$SYSTEM/$BINUTILS"
		ConfigureGcc "Initial"
		BuildGcc "Initial"
		CleaningRemove $GCCBUILD
		QuietExec "rm -fr $BASEDIR/$SYSTEM/$GCC"
	fi

	BuildKos
}

###############################################################################
# Build the Linux compiler
# $1: The system type we're building for
###############################################################################
BuildLinux()
{
	if [ "$1" ]; then
		LogTitle "Making complete $1 Linux compiler"
		# Make sure we're using the right target
		SetOptions $1
	else
		LogTitle "Making complete $TARG Linux compiler"
	fi

	# We firstly need Binutils
	ConfigureBin
	BuildBin

	# uClibc is a bit more straight forward
	if [ "$USEUCLIBC" ]; then
		# uClibc needs to be configured before Gcc so Gcc has the
		# headers
		ConfigureuClibc
	else
		# Here we just install the headers for Gcc
		ConfigureGlibc "Headers"
	fi

	if [ ! "$NATIVECOMPILER" ]; then
		# Initial Gcc using the above headers
		ConfigureGcc "Initial"
		BuildGcc "Initial"
	fi

	if [  "$USEUCLIBC" -a ! "$NATIVECOMPILER" ]; then
		# After the initial Gcc build, we can build the full uClibc
		ConfigureuClibc
		BuilduClibc
	else
		# This looks weird, but we set up the inital Glibc and it
		# installs the headers in "Initial" so Final is used to
		# Build both Initial and Final Glibc
		ConfigureGlibc "Final"
		# This just builds the libs of Glibc to be used with Gcc
		BuildGlibc "Initial"
	fi

	# Build the Gcc that uses the libs from Glibc or uClibc
	ConfigureGcc "Final"
	BuildGcc "Final"

	if [ ! "$USEUCLIBC" -a ! "$NATIVECOMPILER" ]; then
		# Glibc has some extra things that are built now with
		# the bootstrapped compiler
		BuildGlibc "Final"
	fi

	# We don't need sys-include now
	QuietExec "rm -fr $INSTALL/$TARG/sys-include"
}

