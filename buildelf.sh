PWD=`pwd`
SILENT=0
GCCVER="gcc-3.4.6"
BINVER="binutils-2.16.1"
NEWLIBVER="newlib-1.13.0"
PATCHDIR="$PWD/patches"
BINPATCH="$BINVER.diff"
GCCPATCH="$GCCVER.diff"
NEWLIBPATCH="$NEWLIBVER.diff"
#Dreamcast
#PATCHDIR="$PATCHDIR/dc"
#INSTALL="/usr/local/dc"
#BINOPTS="--disable-nls --with-sysroot=$INSTALL"
#GCCOPTS="--with-newlib --disable-nls --enable-symvers=gnu --enable-threads --enable-languages=c,c++"
#NEWLIBOPTS=""
#TARG1="sh4-dreamcast-elf"
#DCTARG="$TARG1"
#TARG2="arm-dreamcast-elf"
#TARG="$TARG1"
#TARGET="--target=$TARG"
#PREFIX="--prefix=$INSTALL"
#Gamecube
PATCHDIR="$PATCHDIR/gc"
INSTALL="/usr/local/gamecube"
GCTARG="powerpc-gekko-elf"
TARG1="$GCTARG"
BINOPTS="--disable-nls --with-sysroot=$INSTALL"
GCCOPTS="--with-cpu=750 --with-gcc --with-gnu-ld --with-gnu-as --with-stabs --with-included-gettext --without-headers --disable-nls --disable-shared --enable-threads --disable-multilib --disable-debug --disable-win32-registry --with-newlib --enable-__cxa_atexit --enable-c99 --enable-long-long --enable-languages=c,c++"
NEWLIBOPTS=""

TARG=$TARG1
TARGET="--target=$TARG"
PREFIX="--prefix=$INSTALL"

BINBUILD="$TARG-binbuildelf"
GCCBUILD="$TARG-gccbuildelf"
NEWLIBBUILD="$TARG-newlibbuildelf"

export PATH=$PATH:$INSTALL/bin

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

UntarPatch()
{
	if ! Untar $1; then
		Patch $2 $1
		Result Patch 
	fi

	CreateDir
}

Untar()
{
	if [ ! -d $1 ]; then
		if [ ! -e $1.tar.bz2 ]; then
			if [ ! -e $1.tar.gz ]; then
				echo "$1.tar.bz2 or $1.tar.gz not found"
				exec false
			else
				echo "Untaring $1.tar.gz"
				tar xfz $1.tar.gz
				return 1
			fi
		else
			echo "Untaring $1.tar.bz2"
			tar xfj $1.tar.bz2
			return 1
		fi
	fi

	return 0
}

Patch()
{
	if [ -e $PATCHDIR/$1 ]; then
		echo "Patching $2"
		cd $PWD/$2
		patch -p1 -i $PATCHDIR/$1
		cd ..
	fi
}

Remove()
{
	echo "Removing contens of $PWD/$1/*"
	rm -fr $PWD/$1/*
}

Result() 
{
	if [ $? -eq 0 ]; then
		echo "$0: $1 completed ok"
	else
		echo "$0: $1 failed to build. Exiting script."
		exec false
	fi
}

CleanInstall()
{
	echo "Cleaning $INSTALL"
	rm -fr $INSTALL/*
}

CleanLocal()
{
	echo "Cleaning $PWD Build files"
	Remove $BINBUILD
	Remove $GCCBUILD
	Remove $NEWLIBBUILD
}

ConfigureBin()
{
	echo "Configuring binutils"
	UntarPatch $BINVER $BINPATCH
	Remove $BINBUILD
	cd $PWD/$BINBUILD 

	if [ $SILENT -eq 0 ]; then
		../$BINVER/configure $PREFIX $TARGET $BINOPTS
	else
		../$BINVER/configure $PREFIX $TARGET $BINOPTS > /dev/null
	fi

	Result ConfigureBin
	cd ..
}

BuildBin()
{
	echo "Building binutils"
	cd $PWD/$BINBUILD

	if [ $SILENT -eq 0 ]; then
		make all 
		make install
	else
		make all > /dev/null
		make install > /dev/null
	fi

	Result BuildBin
	cd ..
}

ConfigureBaseGcc()
{
	echo "Configuring gcc"
	UntarPatch $GCCVER $GCCPATCH
	Remove $GCCBUILD
	cd $PWD/$GCCBUILD

	if [ $SILENT -eq 0 ]; then
		../$GCCVER/configure $TARGET $PREFIX $GCCIOPTS
	else
		../$GCCVER/configure $TARGET $PREFIX $GCCIOPTS > /dev/null
	fi

	Result ConfigureGcc
	cd ..
}

ConfigureFinalGcc()
{
	echo "Configuring gcc"
	UntarPatch $GCCVAR $GCCPATCH
	Remove $GCCBUILD
	cd $PWD/$GCCBUILD

	if [ $SILENT -eq 0 ]; then
		../$GCCVER/configure $TARGET $PREFIX $GCCFOPTS
	else
		../$GCCVER/configure $TARGET $PREFIX $GCCFOPTS > /dev/null
	fi

	Result ConfigureGcc
	cd ..
}

BuildBaseGcc()
{
	echo "Building BaseGCC"
	cd $PWD/$GCCBUILD

	if [ $SILENT -eq 0 ]; then
		make all-gcc 
		make install-gcc 
	else
		make all-gcc > /dev/null
		make install-gcc > /dev/null
	fi

	Result BuildBaseGcc
	cd ..
}

ConfigureNewlib()
{
	echo "Configuring Newlib"
	UntarPatch $NEWLIBVER $NEWLIBPATCH
	rm -fr $PWD/$NEWLIBBUILD/*
	cd $PWD/$NEWLIBBUILD

	if [ $SILENT -eq 0 ]; then
		../$NEWLIBVER/configure $TARGET $PREFIX $NEWLIBOPTS
	else
		../$NEWLIBVER/configure $TARGET $PREFIX $NEWLIBOPTS > /dev/null
	fi

	Result ConfigureNewlib
	cd ..
}

BuildNewlib()
{
	echo "Bulding Newlib"
	cd $PWD/$NEWLIBBUILD

	if [ $SILENT -eq 0 ]; then
		make
		make install
	else
		make > /dev/null
		make install > /dev/null
	fi

	Result BuildNewlib
	cd ..

	if test $TARG = $DCTARG; then
		cp $KOSLOCATION/include/pthread.h $INSTALL/$TARG1/include                       # KOS pthread.h is modified
		cp $KOSLOCATION/include/sys/_pthread.h $INSTALL/$TARG1/include/sys              # to define _POSIX_THREADS
		cp $KOSLOCATION/include/sys/sched.h $INSTALL/$TARG1/include/sys                 # pthreads to kthreads mapping
		ln -nsf $KOSLOCATION/include/kos $INSTALL/$TAR1G/include                        # so KOS includes are available as kos/file.h
		ln -nsf $KOSLOCATION/kernel/arch/dreamcast/include/arch $INSTALL/$TARG1/include # kos/thread.h requires arch/arch.h
		ln -nsf $KOSLOCATION/kernel/arch/dreamcast/include/dc   $INSTALL/$TARG1/include # arch/arch.h requires dc/video.h
	fi
}

BuildFinalGcc()
{
	echo "Building final gcc"
	cd $PWD/$GCCBUILD

	if [ $SILENT -eq 0 ]; then
		make all 
		make install
	else
		make all > /dev/null
		make install > /dev/null
	fi

	Result BuildFinalGcc
	cd ..
}

ConfigureAll()
{
	echo "Configuring all"
	ConfigureBin
	ConfigureGcc
	ConfigureNewlib
}

BuildAll()
{
	echo "Building all"
	BuildBin
	BuildBaseGcc
	BuildNewlib
	BuildFinalGcc
}

All()
{
	echo "Making complete compiler"
	ConfigureBin
	BuildBin
	ConfigureGcc
	BuildBaseGcc
	ConfigureNewlib
	BuildNewlib
	BuildFinalGcc
}

SetTarg2()
{
	TARG=$TARG2
	TARGET="--target=$TARG2"
	PATCHDIR="$PATCHDIR/$TARG2"
}

Usage()
{
	echo "$0 usage"
	echo "	-ci Clean $INSTALL"
	echo "	-c Clean $PWD build files"
	echo "	-clean Clean all"
	echo
	echo "	-conf Configure all"
	echo "	-build Build all in correct order"
	echo "	-all Configure and build all in correct order"
	echo
	echo "	-cb Run configure for binutils"
	echo "	-bb Build and install binutils"
	echo
	echo "	-cig Run configure for initial gcc"
	echo "	-big Build and install inital gcc"
	echo "	-cfg Run configure for final gcc"
	echo "	-bfg Build and install final gcc"
	echo
	echo "	-cm Run configure for Newlib"
	echo "	-bm Build and install Newlib"
	echo
	echo "	(For Dreamcast)"
	echo "	-t2 Set target to two then all calls above work for target two"
	echo
	echo "	-s Build silently (needs /dev/null on system,"
	echo "	   and should be called before all that you want silent)"
}

ParseArgs()
{
	if [ x$1 == x ]; then
		Usage
		exit
	fi

	for i in $*; do
		if
			case $i in
				"-ci")
					CleanInstall
					;;
				"-c")
					CleanLocal
					;;
				"-clean")
					echo "Cleaning all"
					CleanInstall
					CleanLocal
					;;
				"-build")
					BuildAll
					;;
				"-conf")
					ConfigureAll
					;;
				"-all")
					All
					;;
				"-cb")
					ConfigureBin
					;;
				"-bb")
					BuildBin
					;; 
				"-cig")
					ConfigureBaseGcc
					;;
				"-big")
					BuildBaseGcc
					;;
				"-cfg")
					ConfigureFinalGcc
					;;
				"-bfg")
					BuildFinalGcc
					;;
				"-cm")
					ConfigureNewlib
					;;
				"-bm") 
					BuildNewlib
					;;
				"-t2")
					SetTarg2
					;;
				"-s")
					SILENT=1
					;;
			esac; then
				echo "Ignoring unsupported argument \"$i\""
			fi
		done
}

main()
{
	ParseArgs $@
}

main $@

