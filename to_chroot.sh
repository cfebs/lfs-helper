#!/usr/bin/env bash
set -e

VERSION=12.1

if [[ "$(id -u)" != "0" ]]; then
	echo "ERROR: not using root user"
	exit 1;
fi

if [[ -z "$LFS" ]]; then
	echo "ERROR: empty LFS env var, exiting"
	exit 1
fi

echo ">> Changing ownership of setup dirs"
chown -R root:root $LFS/{usr,lib,var,etc,bin,sbin,tools}
case $(uname -m) in
  x86_64) chown -R root:root $LFS/lib64 ;;
esac

echo ">> Creating virtual fs dirs"
mkdir -pv $LFS/{dev,proc,sys,run}

echo ">> Mounting virtual dirs"
mountpoint -q $LFS/dev || mount -v --bind /dev $LFS/dev
mountpoint -q $LFS/dev/pts || mount -vt devpts devpts -o gid=5,mode=0620 $LFS/dev/pts
mountpoint -q $LFS/proc || mount -vt proc proc $LFS/proc
mountpoint -q $LFS/sys || mount -vt sysfs sysfs $LFS/sys
mountpoint -q $LFS/run || mount -vt tmpfs tmpfs $LFS/run
if [ -h $LFS/dev/shm ]; then
  install -v -d -m 1777 $LFS$(realpath /dev/shm)
else
  mountpoint -q $LFS/dev/shm || mount -vt tmpfs -o nosuid,nodev tmpfs $LFS/dev/shm
fi

chroot "$LFS" /usr/bin/env -i   \
    HOME=/root                  \
    TERM="$TERM"                \
    PS1='(lfs chroot) \u:\w\$ ' \
    PATH=/usr/bin:/usr/sbin     \
	MAKEFLAGS="-j$(( $(nproc) - 2 ))" \
    TESTSUITEFLAGS="-j$(( $(nproc) - 2 ))" \
    /bin/bash --login

echo ">> Exited chroot"

echo ">> Cleaning up mounts"
mountpoint -q $LFS/dev/shm && umount $LFS/dev/shm
umount $LFS/dev/pts
umount $LFS/{sys,proc,run,dev}
echo ">> Done"
