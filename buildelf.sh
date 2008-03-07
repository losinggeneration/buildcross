PWD=`pwd`
INSTALL="/usr/local/gamecube"
GCCVER=gcc-3.4.6
BINVER=binutils-2.16.1
NEWLIBVER=newlib-1.13.0
TARG=powerpc-gekko-elf
TARGET=--target=$TARG
PREFIX=--prefix=$INSTALL

mkdir -p buildelfbin buildelfgcc buildelfnewlib

Result() 
{
	if test -e $2; then
		echo "$0: $1 completed ok"
	else
		echo "$0: $1 failed to build. Exiting script."
		exec false
	fi
}

Clean()
{
	echo "Cleaning $INSTALL"
	rm -fr $INSTALL/*
}

CleanAll()
{
	echo "Cleaning all"
	rm -fr $INSTALL/*
	rm -fr buildelfbin/*
	rm -fr buildelfgcc/*
}

ConfigureBin()
{
	echo "Configuring binutils"
	rm -fr $PWD/buildelfbin/*
	cd $PWD/buildelfbin 
	../$BINVER/configure $PREFIX $TARGET --disable-nls --with-sysroot=/usr/local/gamecube
	Result ConfigureBin Makefile
	cd ..
}

BuildBin()
{
	echo "Building binutils"
	cd $PWD/buildelfbin
	make all 
	make install
	Result BuildBin $INSTALL/bin/$TARG-as
	cd ..
}

ConfigureGcc()
{
	echo "Configuring gcc"
	rm -fr $PWD/buildelfgcc/*
	cd $PWD/buildelfgcc
	
	../$GCCVER/configure $TARGET $PREFIX --with-cpu=750 \
		--with-gcc --with-gnu-ld --with-gnu-as --with-stabs --with-included-gettext \
		--without-headers --disable-nls --disable-shared --enable-threads \
		--disable-multilib --disable-debug --disable-win32-registry --with-newlib \
		--enable-__cxa_atexit 	--enable-c99 --enable-long-long --enable-languages=c,c++ 
	Result ConfigureGcc Makefile
	cd ..
}
	
BuildBaseGcc()
{
	echo "Building BaseGCC"
	cd $PWD/buildelfgcc
	make all-gcc 
	make install-gcc 
	Result BuildBaseGcc $INSTALL/bin/$TARG-gcc
	cd ..
}

ConfigureNewlib()
{
	echo "Configuring Newlib"
	rm  -fr $PWD/buildelfnewlib/*
	cd $PWD/buildelfnewlib
	../$NEWLIBVER/configure $TARGET $PREFIX
	Result ConfigureNewlib Makefile
	cd ..
}

BuildNewlib()
{
	echo "Bulding Newlib"
	cd $PWD/buildelfnewlib
	make
	make install
	Result BuildNewlib  $INSTALL/$TARG/lib/libnosys.a
	cd ..
}

BuildFinalGcc()
{
	echo "Building final gcc"
	cd $PWD/buildelfgcc
	make all 
	make install
	Result BuildFinalGcc $INSTALL/bin/$TARG-g++
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

Usage()
{
	echo "$0 usage"
	echo "	-c Clean $INSTALL"
	echo "	-clean Clean all"
	echo
	echo "	-conf Configure all"
	echo "	-build Build all in correct order"
	echo "	-all Configure and build all in correct order"
	echo
	echo "	-cb Run configure for binutils"
	echo "	-bb Build and install binutils"
	echo
	echo "	-cg Run configure for gcc"
	echo "	-big Build and install inital gcc"
	echo "	-bfg Build and install final gcc"
	echo
	echo "	-cm Run configure for Newlib"
	echo "	-bm Build and install Newlib"
}
if [ x$1 == x ]; then
	Usage
	exit
fi
for i in $*; do
	case $i in
		"-c")
			Clean
			;;
		"-clean")
			CleanAll
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
		"-cg")
			ConfigureGcc
			;;
		"-big")
			BuildBaseGcc
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
	esac
done
