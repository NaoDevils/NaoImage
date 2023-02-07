#!/bin/bash

# this script currently requires root access because it uses debootstrap, chroot, chown and mount commands

set -e
set -o pipefail

# check for previous (maybe incomplete?) run
if [ -d ./root-sdk ]; then
    read -p "Remove files from previous run? (y/n) " yn
    case $yn in
        [Yy]* )
            umount ./root-sdk/dev/pts || true
            umount ./root-sdk/dev || true
            umount ./root-sdk/sys || true
            umount ./root-sdk/proc || true
            rm -r root-sdk/
            ;;
        [Nn]* ) exit;;
        * ) echo "Please answer yes or no.";;
    esac
fi

mkdir -p ./root-sdk
debootstrap --variant=buildd --arch=amd64 focal ./root-sdk http://de.archive.ubuntu.com/ubuntu

cat - <<"EOT" > ./root-sdk/etc/apt/sources.list
deb http://de.archive.ubuntu.com/ubuntu focal main restricted universe multiverse
#deb-src http://de.archive.ubuntu.com/ubuntu focal main restricted universe multiverse

deb http://de.archive.ubuntu.com/ubuntu focal-updates main restricted universe multiverse
#deb-src http://de.archive.ubuntu.com/ubuntu focal-updates main restricted universe multiverse

deb http://de.archive.ubuntu.com/ubuntu focal-security main restricted universe multiverse
#deb-src http://de.archive.ubuntu.com/ubuntu focal-security main restricted universe multiverse

deb http://de.archive.ubuntu.com/ubuntu focal-backports main restricted universe multiverse
#deb-src http://de.archive.ubuntu.com/ubuntu focal-backports main restricted universe multiverse
EOT


# install packages, run ldconfig and add users and groups
mount -o bind /dev ./root-sdk/dev
mount -o bind /dev/pts ./root-sdk/dev/pts
mount -t sysfs /sys ./root-sdk/sys
mount -t proc /proc ./root-sdk/proc
chroot ./root-sdk /bin/bash <<"EOT"
set -e 
set -o pipefail

apt-get update
apt-get dist-upgrade -y

DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends opencl-headers ocl-icd-opencl-dev libasound2-dev

exit
EOT
umount ./root-sdk/dev/pts
umount ./root-sdk/dev
umount ./root-sdk/sys
umount ./root-sdk/proc

# clean up
rm -r ./root-sdk/var/lib/apt/lists/* ./root-sdk/var/log/* ./root-sdk/var/cache/*

# disable usr merge
# VS2019 does not handle lib/ symlink correctly for intellisense
# rm ./root-sdk/lib
# mkdir ./root-sdk/lib
# mv ./root-sdk/usr/lib/x86_64-linux-gnu ./root-sdk/lib

# copy CMake toolchain file
cp -av ubuntu.toolchain.cmake ./root-sdk

GIT_IMAGE="$(git rev-parse --short HEAD)"
DATE="$(date +%Y%m%d_%H%M%S)"

tar -I "pigz -9" -C ./root-sdk -cf "naodevils_sdk_${DATE}_${GIT_IMAGE}.tgz" bin/ etc/ lib/ lib64/ root/ sbin/ usr/ var/ ubuntu.toolchain.cmake
