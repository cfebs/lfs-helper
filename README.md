# linux from scratch

Few helper scripts for https://www.linuxfromscratch.org/lfs/view/12.1/

## Usage

Read the scripts first.

```
# take manual steps to setup /mnt/lfs and export to LFS variable for root

$ sudo su -

$ cd /mnt/lfs

# can copy these scripts into /mnt/lfs

# ensure no errors in output from version checks
$ ./version-check.sh

# this will create "lfs" user for building and all the directories needed
$ ./setup.sh

# this will download all the 12.1 sources from a mirror in sources/
$ ./download.sh
```

Swap to `lfs` user
```
# janky shell script that will run through build steps of each package
# a marker is left in sources/${pkg_name}.x after each build
$ ./build.sh

# to rebuild all "targets"
$ rm -f ./sources/*.x
$ ./build.sh
```

TODO as I work through guide
