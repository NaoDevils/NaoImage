#!/bin/bash

# this script currently requires root access because it uses debootstrap, chroot, chown and mount commands

set -e
set -o pipefail

if [ "$#" -lt 2 ]; then
    echo "Illegal number of parameters"
    echo "Usage: $0 nao-image.opn output.ext3 [snippets...]"
    exit 1
fi

# parameters
INPUT_IMAGE="$1"
OUTPUT_IMAGE="$2"

# .opn image offsets
HEADER_SIZE=4096
INSTALLER_OFFSET=$HEADER_SIZE
INSTALLER_SIZE=1048576
IMAGE_OFFSET=$(($INSTALLER_SIZE+$INSTALLER_OFFSET))

# for dd bs
BLOCK_SIZE=4096

mkdir -p ./opn

# copy and extract filesystem and installer from .opn image
if [ "$INPUT_IMAGE" -nt "./opn/installer.sh" ]; then
    echo "Copy installer..."
    dd if="$INPUT_IMAGE" of=./opn/installer.sh skip=$(($INSTALLER_OFFSET/$BLOCK_SIZE)) count=$(($INSTALLER_SIZE/$BLOCK_SIZE)) bs=$BLOCK_SIZE
    sed -i '$ s/\x00*$//' ./opn/installer.sh # remove zeros
    patch ./opn/installer.sh < installer.patch # fix installer
    echo "Done!"
fi

if [ "$INPUT_IMAGE" -nt "./opn/nao.ext3" ]; then
    echo "Copy filesystem..."
    dd if="$INPUT_IMAGE" of="./opn/nao.ext3.gz" skip=$(($IMAGE_OFFSET/$BLOCK_SIZE)) bs=$BLOCK_SIZE
    sed -i '$ s/\x00*$//' ./opn/nao.ext3.gz # remove zeros
    echo "Done!"
    echo "Decompress filesystem..."
    pigz -df "./opn/nao.ext3.gz"
    echo "Done!"
fi

# check for previous (maybe incomplete?) run
if [ -d ./root ]; then
    umount -q ./root/dev/pts || [ $? == 32 ]
    umount -q ./root/dev || [ $? == 32 ]
    umount -q ./root/sys || [ $? == 32 ]
    umount -q ./root/proc || [ $? == 32 ]
    umount -q ./nao || [ $? == 32 ]
    rm -r root/
fi

# check for base system from previous run
SKIP_BASE_SNIPPETS=false
if [ -f ./root.tgz ]; then
    read -p "Use base system from previous run? (y/n) " yn
    case $yn in
        [Yy]* )
            tar -I pigz -xpf ./root.tgz
            SKIP_BASE_SNIPPETS=true
            ;;
        [Nn]* )
            ;;
        * )
            echo "Please answer yes or no."
            exit 2
            ;;
    esac
fi


# execute additional script snippets
while [ $# -gt 2 ]
do
    if [ "$SKIP_BASE_SNIPPETS" == "true" ]; then
        echo "Skipping snippet: $3"
        if [ "$3" == "save-base" ]; then
            SKIP_BASE_SNIPPETS=false
        fi
    else
        echo "Executing snippet: $3"
        . "snippets/$3.sh"
    fi
    shift
done

# clean up
rm -r ./root/var/lib/apt/lists/* ./root/var/log/* ./root/var/cache/*

echo "Installation done! Generate filesystem..."
# generate filesystem with correct UUID and maximum size for Nao's system partition
mke2fs -F -U 42424242-1120-1120-1120-424242424242 -L "NaoDevils-system" -b 4096 -t ext3 -d ./root "$OUTPUT_IMAGE" 999168

echo "Done!"
