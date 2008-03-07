###############################################################################
# Copyright 2000-2006
#         Harley Laue (losinggeneration@yahoo.com) and others (as noted).
#         All rights reserved.
###############################################################################
#!/bin/bash
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
	UntarPatch $BINVER $BINPATCH
	
	# Check if we've already configured. If not, configure
	if ! CheckExists $BINBUILD/.configure; then
		# Remove the contents of the build directory
		Remove $BINBUILD
		# Go to the build directory
		cd $BASEDIR/$BINBUILD 

		ExecuteCmd ../$BINVER/configure $BINOPTS

		# See if configure exited cleanly
		Result "Configuring Binutils"
		touch .configure
	else
		LogTitle "Binutils Already configured"
	fi

	# Go back to the base directory
	cd $BASEDIR
}

###############################################################################
# Build binutils
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
		cd $BASEDIR/$BINBUILD

		ExecuteCmd $MAKE all 
		Result "$MAKE all"
		ExecuteCmd $MAKE install

		# See if the makes exited cleanly
		# This should relatively be ok since install wont work (fully)
		# if make all didn't complete
		Result "Building Binutils"
		touch .installed
	else
		LogTitle "Binutils already installed"
	fi

	# Go back to the base directory
	cd $BASEDIR
}

###############################################################################
# Configure the base gcc for building newlib
###############################################################################
ConfigureBaseGcc()
{
	LogTitle "Configuring initial gcc"
	UntarPatch $GCCVER $GCCPATCH

	# Don't configure base if the final is configured
	if ! CheckExists $GCCBUILD/.finalconfig; then
		if ! CheckExists $GCCBUILD/.configure; then
			Remove $GCCBUILD
			cd $BASEDIR/$GCCBUILD

			ExecuteCmd ../$GCCVER/configure $GCCBOPTS

			Result "Configuring initial Gcc"
			touch .configure
		else
			LogTitle "Gcc already configured"
		fi
	else
		LogTitle "Final gcc already configured, not configuring initial again"
	fi

	cd $BASEDIR
}

###############################################################################
# Build the base gcc for building newlib
###############################################################################
BuildBaseGcc()
{
	LogTitle "Building initial gcc"

	if ! CheckExists $GCCBUILD/.finalconfig; then
		if ! CheckExists $GCCBUILD/.baseinstalled; then
			cd $BASEDIR/$GCCBUILD

			ExecuteCmd $MAKE all-gcc 
			Result "$MAKE all-gcc"
			ExecuteCmd $MAKE install-gcc 
	
			Result "Building initial Gcc"
			touch .baseinstalled
		else
			LogTitle "Initial Gcc already installed"
		fi
	else
		LogTitle "Final gcc already configured, not building initial agian"
	fi
	
	cd $BASEDIR
}

###############################################################################
# Configure newlib
###############################################################################
ConfigureNewlib()
{
	LogTitle "Configuring Newlib"
	UntarPatch $NEWLIBVER $NEWLIBPATCH

	if ! CheckExists $NEWLIBBUILD/.configure; then
		Remove $NEWLIBBUILD
		cd $BASEDIR/$NEWLIBBUILD

		ExecuteCmd ../$NEWLIBVER/configure $NEWLIBOPTS

		Result "Configuring Newlib"
		touch .configure
	else
		LogTitle "Newlib already configured"
	fi

	cd $BASEDIR
}

###############################################################################
# Build and install newlib
###############################################################################
BuildNewlib()
{
	LogTitle "Building Newlib"
	if ! CheckExists $NEWLIBBUILD/.installed; then
		cd $BASEDIR/$NEWLIBBUILD

		ExecuteCmd $MAKE
		Result "$MAKE"
		ExecuteCmd $MAKE install

		Result "Building Newlib"
		touch .installed
	else
		LogTitle "Newlib already installed"
	fi

	cd $BASEDIR

	Download kos
	# SHELF is defined in Dreamcast.cfg
	if [ "x$TARG" == "x$SHELF" -a $THREADS == "posix" -o $THREADS == "yes" ]; then
		###############################################################
		# This was taken from Jim Ursetto's Makefile script to set up
		# some KOS stuff
		###############################################################
		# Only needed for the Dreamcast/kos which is what TARG was
		# created for
		###############################################################
		# I couldn't find any kind of license for this so below may
		# not be covered under the license at the beginning of this
		# file.
		###############################################################
		cp $KOSLOCATION/include/pthread.h $INSTALL/$TARG/include # KOS pthread.h is modified
		cp $KOSLOCATION/include/sys/_pthread.h $INSTALL/$TARG/include/sys # to define _POSIX_THREADS
		cp $KOSLOCATION/include/sys/sched.h $INSTALL/$TARG/include/sys # pthreads to kthreads mapping
		ln -nsf $KOSLOCATION/include/kos $INSTALL/$TARG/include # so KOS includes are available as kos/file.h
		ln -nsf $KOSLOCATION/kernel/arch/dreamcast/include/arch $INSTALL/$TARG/include # kos/thread.h requires arch/arch.h
		ln -nsf $KOSLOCATION/kernel/arch/dreamcast/include/dc $INSTALL/$TARG/include # arch/arch.h requires dc/video.h
		
		LogOutput "Fixing up sh4 newlib includes..."
		LogOutput "cp $KOSLOCATION/include/pthread.h $INSTALL/$TARG/include"
		LogOutput "cp $KOSLOCATION/include/sys/_pthread.h $INSTALL/$TARG/include/sys"
		LogOutput "cp $KOSLOCATION/include/sys/sched.h $INSTALL/$TARG/include/sys"
		LogOutput "ln -nsf $KOSLOCATION/include/kos $INSTALL/$TARG/include"
		LogOutput "ln -nsf $KOSLOCATION/kernel/arch/dreamcast/include/arch $INSTALL/$TARG/include"
		LogOutput "ln -nsf $KOSLOCATION/kernel/arch/dreamcast/include/dc $INSTALL/$TARG/include"
		LogOutput "Fixed some threading stuff for kos"
	fi
}

###############################################################################
# Configure uClibc
###############################################################################
ConfigureuClibc()
{
	LogTitle "Configuring uClibc"
	UntarPatch $UCLIBCVER $UCLIBCPATCH

	if ! CheckExists $UCLIBCDIR/.configure; then
		# uClibc also needs some linux-headers...
		# So get them and extract them
		if [ ! -e $UCLIBCDIR/.headdl ]; then
			ExecuteCmd wget -c http://ep09.pld-linux.org/~mmazur/linux-libc-headers/linux-libc-headers-2.6.12.0.tar.bz2
			Result "Download of linux-libc-headers ok"
			touch $UCLIBCDIR/.headdl
		fi
		if [ ! -e $UCLIBCDIR/.headtar ]; then
			tar xfj linux-libc-headers-2.6.12.0.tar.bz2 -C $TARG
			cd $TARG/linux-libc-headers-2.6.12.0/include
			ln -s asm-sh asm
			touch $BASEDIR/$UCLIBCDIR/.headtar
			cd $BASEDIR 
		fi

		mkdir -p $UCLIBCHDIR/usr/include
		mkdir -p $UCLIBCHDIR/usr/lib
		mkdir -p $UCLIBCHDIR/lib

		cd $BASEDIR/$UCLIBCDIR

		# We just need to copy the configuration file to this 
		# directory and sed out a few things.
		BASELINE=$(echo "$BASEDIR/$TARG" | sed s/\\\//\\\\\\//g)
		UCLIBCLINE=$(echo "$UCLIBCHDIR" | sed s/\\\//\\\\\\//g)

		sed "s/KERNELSOURCEDIR/$BASELINE\/linux-libc-headers-2.6.12.0/" $PATCHDIR/uclibc-config | sed "s/COMPILERPREFIX/$TARG-/" | sed "s/SHAREDLIBPREFIX/$UCLIBCLINE\//" |  sed "s/RUNDEVPREFIX/$UCLIBCLINE\/usr/" > .config

		ExecuteCmd make PREFIX=$UCLIBCHDIR DEVEL_PREFIX=/usr/ RUNTIME_PREFIX=$UCLIBCHDIR pregen install_dev
		Result "Configuring uClibc"
		touch .configure
	else
		LogTitle "uClibc already configured"
	fi

	cd $BASEDIR
}

###############################################################################
# Build and install uClibc
###############################################################################
BuilduClibc()
{
	LogTitle "Building uClibc"
	if ! CheckExists $UCLIBCDIR/.installed; then
		cd $BASEDIR/$UCLIBCDIR

		ExecuteCmd $MAKE
		Result "$MAKE"
		ExecuteCmd $MAKE install

		Result "Building uClibc"
		# Ok, building went ok, so install the libs and includes
	        # to the right prefix
		cp -r $UCLIBCHDIR/usr/include $INSTALL
		cp -r $UCLIBCHDIR/usr/lib/* $INSTALL/lib
		cd $INSTALL/$TARG
		ln -snf ../include sys-include
		ln -snf ../include include
		mv lib/* ../lib
		rm -fr lib
		ln -snf ../lib lib
		cd -
		touch .installed
	else
		LogOutput "uClibc already installed"
	fi

	cd $BASEDIR
}

###############################################################################
# Configure the final gcc for you to use
###############################################################################
ConfigureFinalGcc()
{
	LogTitle "Configuring final Gcc"
	UntarPatch $GCCVER $GCCPATCH

	if ! CheckExists $GCCBUILD/.finalconfig; then
		# I don't like seeing "(reconfigured)" from gcc
		Remove $GCCBUILD
	
		cd $BASEDIR/$GCCBUILD

		ExecuteCmd ../$GCCVER/configure $GCCFOPTS

		Result "Configuring final Gcc"
		touch .finalconfig
	else
		LogTitle "Gcc Already configured"
	fi

	cd $BASEDIR
}

###############################################################################
# Build the final gcc for you to use
###############################################################################
BuildFinalGcc()
{
	LogTitle "Building final Gcc"
	
	if ! CheckExists $GCCBUILD/.finalinstalled; then
		cd $BASEDIR/$GCCBUILD

		ExecuteCmd $MAKE all 
		Result "$MAKE all"
		ExecuteCmd $MAKE install

		Result "Building final Gcc"
		touch .finalinstalled
	else
		LogTitle "Final Gcc already installed"
	fi

	cd $BASEDIR
}

###############################################################################
# Build Kos for Dreamcast
###############################################################################
BuildKos()
{
	LogTitle "Building kos"
	if [ ! -d $KOSLOCATION -o ! -d $KOSLOCATION/../kos-ports ]; then
		Download kos
	fi

	cd $KOSLOCATION

	#######################################################################
	# This is to setup the environ.sh to what our compiler is
	#######################################################################
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

	COMPLOC=`echo $INSTALL | sed s/\\\//\\\\\\\\\\\//g`
	if [ x$TARG == x$SHELF -o x$TARG == x$ARMELF ]; then
		# Same as above for DC_ARM_BASE, but we use where the compiler is
		# installed instead
		ARMBASELINE=$(grep "^export DC_ARM_BASE\=" environ.sh | sed s/\"/\\\\\"/g)
		ARMBASELINE=$(echo "$ARMBASELINE" | sed s/\\\//\\\\\\//g)
		sed "s/$ARMBASELINE/export DC_ARM_BASE=\"$COMPLOC\"/" environ.sh > temp 
		mv temp environ.sh
		
		# Same as above for DC_ARM_BASE, but we use where the compiler is
		# installed instead
		ARMPREFIXLINE=$(grep "^export DC_ARM_PREFIX\=" environ.sh | sed s/\"/\\\\\"/g)
		ARMPREFIXLINE=$(echo "$ARMPREFIXLINE" | sed s/\\\//\\\\\\//g)
		sed "s/$ARMPREFIXLINE/export DC_ARM_PREFIX=\"$ARMELF\"/" environ.sh > temp
		mv temp environ.sh

		# Needed because we can't just use $SHELF for the cc prefix anymore
		THISTARG=$SHELF
	else
		# if the arch isn't Dreamcast, it's ia32
		ARCHBASELINE=$(grep "^export KOS_ARCH=\"dreamcast\"" environ.sh)
		sed "s/$ARCHBASELINE/export KOS_ARCH=\"ia32\"/" environ.sh > temp
		mv temp environ.sh

		# Comment these two out if it's not the dreamcast compiler
		ARMBASELINE=$(grep "^export DC_ARM_BASE\=" environ.sh | sed s/\"/\\\\\"/g)
		ARMBASELINE=$(echo "$ARMBASELINE" | sed s/\\\//\\\\\\//g)
		sed "s/$ARMBASELINE/#export DC_ARM_BASE=/" environ.sh > temp 
		mv temp environ.sh
		
		ARMPREFIXLINE=$(grep "^export DC_ARM_PREFIX\=" environ.sh | sed s/\"/\\\\\"/g)
		ARMPREFIXLINE=$(echo "$ARMPREFIXLINE" | sed s/\\\//\\\\\\//g)
		sed "s/$ARMPREFIXLINE/#export DC_ARM_PREFIX=/" environ.sh > temp
		mv temp environ.sh

		THISTARG=$TARG
	fi
	
	# Same as above but for KOS_CC_BASE
	KOSCCBASELINE=$(grep "^export KOS_CC_BASE\=" environ.sh | sed s/\"/\\\\\"/g)
	KOSCCBASELINE=$(echo $KOSCCBASELINE | sed s/\\\//\\\\\\//g)
	sed "s/$KOSCCBASELINE/export KOS_CC_BASE=\"$COMPLOC\"/g" environ.sh > temp
	mv temp environ.sh

	# Change the standard dc to our prefix
	KOSCCPREFIXLINE=$(grep "^export KOS_CC_PREFIX=" environ.sh | sed s/\"/\\\\\"/g)
	KOSCCPREFIXLINE=$(echo $KOSCCPREFIXLINE | sed s/\\\//\\\\\\//g)
	sed "s/$KOSCCPREFIXLINE/export KOS_CC_PREFIX=\"$THISTARG\"/g" environ.sh > temp
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
	#######################################################################

	# Set environ.sh variables to use
	source environ.sh
	
	Patch kos $KOSPATCH
	cd $KOSLOCATION
	# make kos
	ExecuteCmd $MAKE clean
	ExecuteCmd $MAKE
	Result "Building KOS"

	Patch kos-ports $KOSPORTSPATCH
	# make kos-ports
	cd $KOSLOCATION/../kos-ports
	ExecuteCmd $MAKE clean
	ExecuteCmd $MAKE
	Result "Building KOS ports"
}

###############################################################################
# Do it all in a relatively sane manor ;)
###############################################################################
All()
{
	LogTitle "Making complete compiler"
	ConfigureBin
	BuildBin
	ConfigureBaseGcc
	BuildBaseGcc
	ConfigureNewlib
	BuildNewlib
	ConfigureFinalGcc
	BuildFinalGcc
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
	rm -fr $BASEDIR/$TARG/$BINVER
	ConfigureBaseGcc
	BuildBaseGcc
	CleaningRemove $GCCBUILD
	rm -fr $BASEDIR/$TARG/$GCCVER
	ConfigureNewlib
	BuildNewlib
	CleaningRemove $NEWLIBBUILD
	rm -fr $BASEDIR/$TARG/$NEWLIBVER
	ConfigureFinalGcc
	BuildFinalGcc
	CleaningRemove $GCCBUILD
	rm -fr $BASEDIR/$TARG/$GCCVER
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

	# The default is to do a single pass without newlib for target (arm)
	if [ $TWOPASS -eq 1 ]; then
		All
	else
		ConfigureBin
		BuildBin
		ConfigureBaseGcc
		BuildBaseGcc
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

	# The default is to do a single pass without newlib for target 2 (arm)
	if [ $TWOPASS -eq 1 ]; then
		CleaningAll
	else
		ConfigureBin
		BuildBin
		CleaningRemove $BINBUILD
		rm -fr $BASEDIR/$TARG/$BINVER
		ConfigureBaseGcc
		BuildBaseGcc
		CleaningRemove $GCCBUILD
		rm -fr $BASEDIR/$TARG/$GCCVER
	fi

	BuildKos
}

###############################################################################
# Build the Dreamcast Linux compiler
###############################################################################
BuildDcLinux()
{
	LogTitle "Making complete Dreamcast Linux compiler"
	# Make sure we're using the right target	
	SetOptions DcLinux
	ConfigureBin
	BuildBin
	# uClibc needs to be configured before Gcc
	ConfigureuClibc
	ConfigureBaseGcc
	BuildBaseGcc
	ConfigureuClibc
	BuilduClibc
	ConfigureFinalGcc
	BuildFinalGcc
	rm $INSTALL/$TARG/sys-include
}

