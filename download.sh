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

pushd $LFS/sources
wget -r -l 1 -nd https://lfs.gnlug.org/pub/lfs/lfs-packages/${VERSION}/
curl -sL -O https://www.linuxfromscratch.org/lfs/downloads/${VERSION}/md5sums
popd
