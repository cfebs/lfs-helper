#!/usr/bin/env bash
set -e

VERSION=12.1

if [[ "$(id -u)" != "0" ]]; then
	echo "ERROR: not root user for build, exiting"
	exit 1;
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
# Initial dirs setup
################################################################################
mkdir -pv /etc/{opt,sysconfig}
mkdir -pv /lib/firmware
mkdir -pv /media/{floppy,cdrom}
mkdir -pv /usr/{,local/}{include,src}
mkdir -pv /usr/local/{bin,lib,sbin}
mkdir -pv /usr/{,local/}share/{color,dict,doc,info,locale,man}
mkdir -pv /usr/{,local/}share/{misc,terminfo,zoneinfo}
mkdir -pv /usr/{,local/}share/man/man{1..8}
mkdir -pv /var/{cache,local,log,mail,opt,spool}
mkdir -pv /var/lib/{color,misc,locate}

ln -sfv /run /var/run
ln -sfv /run/lock /var/lock

install -dv -m 0750 /root
install -dv -m 1777 /tmp /var/tmp

ln -f -sv /proc/self/mounts /etc/mtab

cat > /etc/hosts << EOF
127.0.0.1  localhost $(hostname)
::1        localhost
EOF

cat > /etc/passwd << "EOF"
root:x:0:0:root:/root:/bin/bash
bin:x:1:1:bin:/dev/null:/usr/bin/false
daemon:x:6:6:Daemon User:/dev/null:/usr/bin/false
messagebus:x:18:18:D-Bus Message Daemon User:/run/dbus:/usr/bin/false
uuidd:x:80:80:UUID Generation Daemon User:/dev/null:/usr/bin/false
nobody:x:65534:65534:Unprivileged User:/dev/null:/usr/bin/false
tester:x:101:101::/home/tester:/bin/bash
EOF

cat > /etc/group << "EOF"
root:x:0:
bin:x:1:daemon
sys:x:2:
kmem:x:3:
tape:x:4:
tty:x:5:
daemon:x:6:
floppy:x:7:
disk:x:8:
lp:x:9:
dialout:x:10:
audio:x:11:
video:x:12:
utmp:x:13:
cdrom:x:15:
adm:x:16:
messagebus:x:18:
input:x:24:
mail:x:34:
kvm:x:61:
uuidd:x:80:
wheel:x:97:
users:x:999:
nogroup:x:65534:
tester:x:101:
EOF

install -o tester -d /home/tester

touch /var/log/{btmp,lastlog,faillog,wtmp}
chgrp -v utmp /var/log/lastlog
chmod -v 664  /var/log/lastlog
chmod -v 600  /var/log/btmp

################################################################################
# gettext
################################################################################

_build_gettext() {
	tar -xvf gettext-*.tar.xz
	cd gettext-*/

	./configure --disable-shared
	make
	cp -v gettext-tools/src/{msgfmt,msgmerge,xgettext} /usr/bin
}

_build_thing "gettext"


################################################################################
# bison
################################################################################

_build_bison() {
	tar -xvf bison-*.tar.xz
	cd bison-*/

	./configure --prefix=/usr \
		    --docdir=/usr/share/doc/bison-3.8.2

	make
	make install
}

_build_thing "bison"


################################################################################
# perl
################################################################################

_build_perl() {
	tar -xvf perl-*.tar.xz
	cd perl-*/


	sh Configure -des                                        \
		     -Dprefix=/usr                               \
		     -Dvendorprefix=/usr                         \
		     -Duseshrplib                                \
		     -Dprivlib=/usr/lib/perl5/5.38/core_perl     \
		     -Darchlib=/usr/lib/perl5/5.38/core_perl     \
		     -Dsitelib=/usr/lib/perl5/5.38/site_perl     \
		     -Dsitearch=/usr/lib/perl5/5.38/site_perl    \
		     -Dvendorlib=/usr/lib/perl5/5.38/vendor_perl \
		     -Dvendorarch=/usr/lib/perl5/5.38/vendor_perl

	make
	make install
}

_build_thing "perl"

################################################################################
# Python p1
################################################################################

_build_python_p1() {
	tar -xvf Python-*.tar.xz
	cd Python-*/


	./configure --prefix=/usr   \
		    --enable-shared \
		    --without-ensurepip

	make
	make install
}

_build_thing "python_p1"

################################################################################
# texinfo
################################################################################

_build_texinfo() {
	tar -xvf texinfo-*.tar.xz
	cd texinfo-*/

	./configure --prefix=/usr
	make
	make install
}

_build_thing "texinfo"

################################################################################
# util-linux
################################################################################

_build_util-linux() {
	tar -xvf util-linux-*.tar.xz
	cd util-linux-*/

	mkdir -pv /var/lib/hwclock
	./configure --libdir=/usr/lib    \
		    --runstatedir=/run   \
		    --disable-chfn-chsh  \
		    --disable-login      \
		    --disable-nologin    \
		    --disable-su         \
		    --disable-setpriv    \
		    --disable-runuser    \
		    --disable-pylibmount \
		    --disable-static     \
		    --without-python     \
		    ADJTIME_PATH=/var/lib/hwclock/adjtime \
		    --docdir=/usr/share/doc/util-linux-2.39.3
	make
	make install
}

_build_thing "util-linux"

################################################################################
# post build steps
################################################################################

echo ">> Removing docs, .la files, /tools"
rm -rf /usr/share/{info,man,doc}/*
find /usr/{lib,libexec} -name \*.la -delete
rm -rf /tools

echo ">> You can now exit the chroot and make a toolchain backup"

################################################################################
# TODO
################################################################################
#
#_build_TODO() {
#	tar -xvf TODO-*.tar.xz
#	cd TODO-*/
#	# TODO
#}
#
#_build_thing "TODO"
