echo "Cleaning /usr/local/gamecube" > log.err
cd /usr/local/gamecube
rm -fr *
cd -
mkdir -p buildbin buildgcc buildnewlib

echo "Building binutils" >> log.err
cd buildbin
rm -fr *
../binutils-2.15/configure --prefix=/usr/local/gamecube --target=powerpc-gekko-elf --with-cpu=gekko --with-cpu=750 --disable-nls --with-newlib --disable-multilib 2>> ../log.err
make all  2>> ../log.err
make install  2>> ../log.err

echo "Building BaseGCC" >> ../log.err
cd ../buildgcc
rm  -fr *
../gcc-3.4.4/configure --prefix=/usr/local/gamecube --target=powerpc-gekko-elf --with-cpu=gekko --with-cpu=750 --disable-nls --with-newlib --disable-multilib -v --enable-languages=c 2>> ../log.err
make all-gcc  2>> ../log.err
make install-gcc  2>> ../log.err

echo "Bulding NewLib" >> ../log.err
cd ../buildnewlib
rm -fr *
../newlib-1.13.0/configure --prefix=/usr/local/gamecube --target=powerpc-gekko-elf --with-cpu=gekko --with-cpu=750 --disable-nls --with-newlib --disable-multilib 2>> ../log.err
make  2>> ../log.err
make install  2>> ../log.err

echo "Building final gcc" >> ../log.err
cd ../buildgcc
rm -fr *
../gcc-3.4.4/configure --prefix=/usr/local/gamecube/ --target=powerpc-gekko-elf --with-cpu=gekko --with-cpu=750 --with-gcc --with-gnu-ld --with-gnu-as --with-stabs --with-included-gettext --without-headers --disable-nls --disable-shared --disable-threads --disable-multilib --disable-win32-registry --with-newlib -v --enable-languages=c,c++  2>> ../log.err
make all  2>> ../log.err
make install  2>> ../log.err
