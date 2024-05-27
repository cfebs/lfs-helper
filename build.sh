#!/usr/bin/env bash
set -e

VERSION=12.1

if [[ "$(id -nu $(id -u))" != "lfs" ]]; then
	echo "ERROR: not lfs user, exiting"
	exit 1;
fi

if [[ "$(id -u)" == "0" ]]; then
	echo "ERROR: using root user for build, exiting"
	exit 1;
fi

if [[ -z "$LFS" ]]; then
	echo "ERROR: empty LFS env var, exiting"
	exit 1
fi

_build_thing() {
	name="$1"
	if [[ -z "$name" ]]; then
		echo "ERROR: no name provide"
		return 1
	fi
	if [[ "$name" == "TODO" ]]; then
		echo "ERROR: bad TODO name provided"
		return 1
	fi
	marker="$LFS/sources/${name}.x"

	cd $LFS/sources
	echo ">> Building: ${name}"

	if [[ ! -e "$marker" ]]; then
		_build_${name}

		touch "$marker"
	else
		echo ">> Skipping: $marker exists"
	fi

	cd $LFS/sources
	echo ">> Building done: ${name}"
}

################################################################################
# binutils
################################################################################

_build_binutils() {
	tar -xvf binutils-*.tar.xz
	cd binutils-*/
	mkdir -p -v build
	cd       build
	../configure --prefix=$LFS/tools \
		     --with-sysroot=$LFS \
		     --target=$LFS_TGT   \
		     --disable-nls       \
		     --enable-gprofng=no \
		     --disable-werror    \
		     --enable-default-hash-style=gnu

	make
	make install
}

_build_thing 'binutils'

################################################################################
# gcc p1
################################################################################

_build_gcc_p1() {
	tar -xvf gcc-*.tar.xz
	cd gcc-*/
	rm -rf ./mpfr ./gmp ./mpc
	tar -xf ../mpfr-4.2.1.tar.xz
	mv -v -f mpfr-4.2.1 mpfr
	tar -xf ../gmp-6.3.0.tar.xz
	mv -v -f gmp-6.3.0 gmp
	tar -xf ../mpc-1.3.1.tar.gz
	mv -v -f mpc-1.3.1 mpc

	case $(uname -m) in
	  x86_64)
	    sed -e '/m64=/s/lib64/lib/' \
		-i.orig gcc/config/i386/t-linux64
	 ;;
	esac

	mkdir -p -v build
	cd       build

	../configure                  \
	    --target=$LFS_TGT         \
	    --prefix=$LFS/tools       \
	    --with-glibc-version=2.39 \
	    --with-sysroot=$LFS       \
	    --with-newlib             \
	    --without-headers         \
	    --enable-default-pie      \
	    --enable-default-ssp      \
	    --disable-nls             \
	    --disable-shared          \
	    --disable-multilib        \
	    --disable-threads         \
	    --disable-libatomic       \
	    --disable-libgomp         \
	    --disable-libquadmath     \
	    --disable-libssp          \
	    --disable-libvtv          \
	    --disable-libstdcxx       \
	    --enable-languages=c,c++

	make
	make install

	cd ..
	cat gcc/limitx.h gcc/glimits.h gcc/limity.h > \
	  `dirname $($LFS_TGT-gcc -print-libgcc-file-name)`/include/limits.h
}

_build_thing 'gcc_p1'

################################################################################
# linux_api_headers
################################################################################

_build_linux_api_headers() {
	tar -xvf linux-*.tar.xz
	cd linux-*/

	make mrproper
	make headers
	find usr/include -type f ! -name '*.h' -delete
	cp -rv usr/include $LFS/usr
}

_build_thing "linux_api_headers"

################################################################################
# glibc
################################################################################

_build_glibc() {
	tar -xvf glibc-*.tar.xz
	cd glibc-*/

	case $(uname -m) in
	    i?86)   ln -sfv ld-linux.so.2 $LFS/lib/ld-lsb.so.3
	    ;;
	    x86_64) ln -sfv ../lib/ld-linux-x86-64.so.2 $LFS/lib64
		    ln -sfv ../lib/ld-linux-x86-64.so.2 $LFS/lib64/ld-lsb-x86-64.so.3
	    ;;
	esac

	patch -Np1 -i ../glibc-2.39-fhs-1.patch

	mkdir -p -v build
	cd       build

	echo "rootsbindir=/usr/sbin" > configparms
	../configure                             \
	      --prefix=/usr                      \
	      --host=$LFS_TGT                    \
	      --build=$(../scripts/config.guess) \
	      --enable-kernel=4.19               \
	      --with-headers=$LFS/usr/include    \
	      --disable-nscd                     \
	      libc_cv_slibdir=/usr/lib

	make
	make DESTDIR=$LFS install
	sed '/RTLDLIST=/s@/usr@@g' -i $LFS/usr/bin/ldd
}

_build_thing "glibc"

################################################################################
# libstdcpp (Libstdc++)
################################################################################

_build_libstdcpp() {
	tar -xvf gcc-*.tar.xz
	cd gcc-*/

	mkdir -p -v buildcpp
	cd       buildcpp

	../libstdc++-v3/configure           \
	    --host=$LFS_TGT                 \
	    --build=$(../config.guess)      \
	    --prefix=/usr                   \
	    --disable-multilib              \
	    --disable-nls                   \
	    --disable-libstdcxx-pch         \
	    --with-gxx-include-dir=/tools/$LFS_TGT/include/c++/13.2.0

	make
	make DESTDIR=$LFS install
	rm -v $LFS/usr/lib/lib{stdc++{,exp,fs},supc++}.la
}

_build_thing "libstdcpp"

################################################################################
# m4
################################################################################

_build_m4() {
	tar -xvf m4-*.tar.xz
	cd m4-*/

	./configure --prefix=/usr   \
		    --host=$LFS_TGT \
		    --build=$(build-aux/config.guess)

	make
	make DESTDIR=$LFS install
}

_build_thing "m4"

################################################################################
# ncurses
################################################################################

_build_ncurses() {
	tar -xvf ncurses-*.tar.xz
	cd ncurses-*/

	sed -i s/mawk// configure

	mkdir -p build
	pushd build
	  ../configure
	  make -C include
	  make -C progs tic
	popd

	./configure --prefix=/usr                \
		    --host=$LFS_TGT              \
		    --build=$(./config.guess)    \
		    --mandir=/usr/share/man      \
		    --with-manpage-format=normal \
		    --with-shared                \
		    --without-normal             \
		    --with-cxx-shared            \
		    --without-debug              \
		    --without-ada                \
		    --disable-stripping          \
		    --enable-widec

	make

	make DESTDIR=$LFS TIC_PATH=$(pwd)/build/progs/tic install
	ln -sv libncursesw.so $LFS/usr/lib/libncurses.so
	sed -e 's/^#if.*XOPEN.*$/#if 1/' \
	    -i $LFS/usr/include/curses.h
}

_build_thing "ncurses"

################################################################################
# bash
################################################################################

_build_bash() {
	tar -xvf bash-*.tar.gz
	cd bash-*/

	./configure --prefix=/usr                      \
		    --build=$(sh support/config.guess) \
		    --host=$LFS_TGT                    \
		    --without-bash-malloc

	make
	make DESTDIR=$LFS install
	ln -sv bash $LFS/bin/sh
}

_build_thing "bash"

################################################################################
# coreutils
################################################################################

_build_coreutils() {
	tar -xvf coreutils-*.tar.xz
	cd coreutils-*/

	./configure --prefix=/usr                     \
		    --host=$LFS_TGT                   \
		    --build=$(build-aux/config.guess) \
		    --enable-install-program=hostname \
		    --enable-no-install-program=kill,uptime

	make
	make DESTDIR=$LFS install

	mv -v $LFS/usr/bin/chroot              $LFS/usr/sbin
	mkdir -pv $LFS/usr/share/man/man8
	mv -v $LFS/usr/share/man/man1/chroot.1 $LFS/usr/share/man/man8/chroot.8
	sed -i 's/"1"/"8"/'                    $LFS/usr/share/man/man8/chroot.8
}

_build_thing "coreutils"

################################################################################
# diffutils
################################################################################

_build_diffutils() {
	tar -xvf diffutils-*.tar.xz
	cd diffutils-*/

	./configure --prefix=/usr   \
		    --host=$LFS_TGT \
		    --build=$(./build-aux/config.guess)

	make
	make DESTDIR=$LFS install
}

_build_thing "diffutils"

################################################################################
# file
################################################################################

_build_file() {
	tar -xvf file-*.tar.gz
	cd file-*/

	mkdir -p build
	pushd build
	../configure --disable-bzlib      \
	             --disable-libseccomp \
	             --disable-xzlib      \
	             --disable-zlib
	make
	popd

	./configure --prefix=/usr --host=$LFS_TGT --build=$(./config.guess)
	make FILE_COMPILE=$(pwd)/build/src/file
	make DESTDIR=$LFS install
	rm -v $LFS/usr/lib/libmagic.la
}

_build_thing "file"

################################################################################
# findutils
################################################################################

_build_findutils() {
	tar -xvf findutils-*.tar.xz
	cd findutils-*/

	./configure --prefix=/usr                   \
		    --localstatedir=/var/lib/locate \
		    --host=$LFS_TGT                 \
		    --build=$(build-aux/config.guess)

	make
	make DESTDIR=$LFS install
}

_build_thing "findutils"


################################################################################
# gawk
################################################################################

_build_gawk() {
	tar -xvf gawk-*.tar.xz
	cd gawk-*/

	sed -i 's/extras//' Makefile.in
	./configure --prefix=/usr   \
		    --host=$LFS_TGT \
		    --build=$(build-aux/config.guess)
	make
	make DESTDIR=$LFS install
}

_build_thing "gawk"

################################################################################
# grep
################################################################################

_build_grep() {
	tar -xvf grep-*.tar.xz
	cd grep-*/

	./configure --prefix=/usr   \
		    --host=$LFS_TGT \
		    --build=$(./build-aux/config.guess)
	make
	make DESTDIR=$LFS install
}

_build_thing "grep"

################################################################################
# gzip
################################################################################

_build_gzip() {
	tar -xvf gzip-*.tar.xz
	cd gzip-*/

	./configure --prefix=/usr --host=$LFS_TGT	
	make
	make DESTDIR=$LFS install
}

_build_thing "gzip"

################################################################################
# TMPL
################################################################################
#
#_build_TODO() {
#	tar -xvf TODO-*.tar.xz
#	cd TODO-*/
#	TODO
#}
#
#_build_thing "TODO"
