#!/usr/bin/env bash

VERSION=12.1

if [[ -z "$LFS" ]]; then
	echo "ERROR: empty LFS env var"
	exit 1
fi

if [[ "$(id -u)" != "0" ]]; then
	echo "ERROR: not run as root"
	exit 1
fi

if [[ ! -d "/mnt/lfs" ]]; then
	echo "ERROR: /mnt/lfs does not exist"
	exit 1
fi

groupadd lfs
useradd -s /bin/bash -g lfs -m -k /dev/null lfs

cat > /home/lfs/.bash_profile << "EOF"
exec env -i HOME=$HOME TERM=$TERM PS1='\u:\w\$ ' /bin/bash
EOF

cat > /home/lfs/.bashrc << "EOF"
set +h
umask 022
LFS=/mnt/lfs
LC_ALL=POSIX
LFS_TGT=$(uname -m)-lfs-linux-gnu
PATH=/usr/bin
if [ ! -L /bin ]; then PATH=/bin:$PATH; fi
PATH=$LFS/tools/bin:$PATH
CONFIG_SITE=$LFS/usr/share/config.site
export LFS LC_ALL LFS_TGT PATH CONFIG_SITE
export MAKEFLAGS=-j$(( $(nproc) - 2 ))
EOF

mkdir -p $LFS
mkdir -p -v $LFS/sources
chmod -v a+wt $LFS/sources

mkdir -pv $LFS/{etc,var} $LFS/usr/{bin,lib,sbin}
for i in bin lib sbin; do
  ln -sv usr/$i $LFS/$i
done

case $(uname -m) in
  x86_64) mkdir -pv $LFS/lib64 ;;
esac

mkdir -pv $LFS/tools

chown -v -R lfs $LFS/{lib,var,etc,bin,sbin,tools}
case $(uname -m) in
  x86_64) chown -v lfs $LFS/lib64 ;;
esac
