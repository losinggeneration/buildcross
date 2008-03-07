PWD=`pwd`
INSTALL="/usr/local/gc-linux"

mkdir -p buildlinuxbin buildlinuxgcc buildlinuxuclibc buildlinuxuclibcpp

Clean()
{
	echo "Cleaning $INSTALL"
	rm -fr $INSTALL/*
}

CleanAll()
{
	echo "Cleaning all"
	rm -fr $INSTALL/*
	rm -fr buildlinuxbin/*
	rm -fr buildlinuxgcc/*
	rm -fr buildlinuxuclibc/*
	rm -fr buildlinuxuclibcpp/*
}

ConfigureBin()
{
	echo "Configuring binutils"
	rm -fr $PWD/buildlinuxbin/*
	cd $PWD/buildlinuxbin 
	../binutils-2.16.1/configure --prefix=/usr/local/gc-linux \
		--target=powerpc-gekko-linux-uclibc --disable-nls --with-sysroot=/usr/local/gc-linux
	cd ..
}

BuildBin()
{
	echo "Building binutils"
	cd $PWD/buildlinuxbin
	make all 
	make install
	cd ..
}

ConfigureBaseGcc()
{
	echo "Configuring gcc"
	rm -fr $PWD/buildlinuxgcc/*
	cd $PWD/buildlinuxgcc
	../gcc-3.4.4/configure --prefix=/usr/local/gc-linux --target=powerpc-gekko-linux-uclibc \
		--with-local-prefix=/usr/local/gc-linux \
		--disable-multilib --with-newlib --without-headers \
		--disable-nls --enable-threads=no --enable-symvers=gnu \
		--enable-__cxa_atexit  --disable-shared --enable-languages=c \

	cd ..
}
	
BuildBaseGcc()
{
	echo "Building BaseGCC"
	cd $PWD/buildlinuxgcc
	make all-gcc 
	make install-gcc 
	cd ..
}

ConfigureuClibc()
{
	echo "Configuring uClibc"
	rm  -fr $PWD/buildlinuxuclibc/*
	cd $PWD/buildlinuxuclibc
	make -C ../uClibc-0.9.28 menuconfig
	cd ..
}

BuilduClibc()
{
	echo "Bulding uClibc"
	cd $PWD/buildlinuxuclibc
	make -C ../uClibc-0.9.28
	make -C ../uClibc-0.9.28 install
	cd ..
}

ConfigureuClibcpp()
{
	echo "Configuring uClibc++"
	rm -fr $PWD/buildlinuxuclibcpp/*
	cd $PWD/buildlinuxuclibcpp
	make -C ../uClibc++-0.2.0 menuconfig
	cd ..
}
	
BuilduClibcpp()
{
	echo "Building uClibc++"
	cd $PWD/buildlinuxuclibcpp
	make -C ../uClibc++-0.2.0
	make -C ../uClibc++-0.2.0 install
	cd ..
}

ConfigureFinalGcc()
{
	echo "Configuring gcc"
	rm -fr $PWD/buildlinuxgcc/*
	cd $PWD/buildlinuxgcc
	../gcc-3.4.4/configure --prefix=/usr/local/gc-linux --target=powerpc-gekko-linux-uclibc \
		--with-headers=/home/harley/gamecube/gcc/uClibc-0.9.28/include \
		--with-local-prefix=/usr/local/gc-linux/powerpc-gekko-linux-uclibc \
		--disable-nls \
		--enable-threads=posix \
		--enable-symvers=uclibc \
		--enable-__cxa_atexit \
		--enable-languages=c,c++ \
		--enable-c99 \
		--enable-long-long
	cd ..

}

BuildFinalGcc()
{
	echo "Building final gcc"
	cd $PWD/buildlinuxgcc
	make all 
	make install 
	cd ..
}

ConfigureAll()
{
	echo "Configuring all"
	ConfigureBin
	ConfigureBaseGcc
	ConfigureuClibc
	ConfigureuClibcpp
}

BuildAll()
{
	BuildBin
	BuildBaseGcc
	BuilduClibc
	BuilduClibcpp
	BuildFinalGcc
}

Usage()
{
	echo "$0 usage"
	echo "	-c Clean $INSTALL"
	echo "	-clean Clean all"
	echo
	echo "	-conf Configure all"
	echo "	-build Build all"
	echo
	echo "	-cb Run configure on binutils"
	echo "	-bb Build and install binutils"
	echo
	echo "	-cig Run configure initial gcc"
	echo "	-big Build and install inital gcc"
	echo "	-cfg Run configure for final gcc"
	echo "	-bfg Build and install final gcc"
	echo
	echo "	-cu Run menuconfig on uClibc"
	echo "	-bu Build and install uClibc"
	echo
	echo "	-cp Run menuconfig on uClibc++"
	echo "	-bp Build an install uClibc++"
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
		"-cu")
			ConfigureuClibc
			;;
		"-bu") 
			BuilduClibc
			;;
		"-cp")
			ConfigureuClibcpp
			;;
		"-bp") 
			BuilduClibcpp
	esac
done
