#!/bin/bash

set -e
set -o pipefail

### IMAGE SETTINGS

MAGIC_NUMBER="ALDIMAGE"

# 8=Factory reset
# 4=Fast erase
# 2=Keep image
# 1=Halt after upgrade
FLAGS='\x80'

INSTALLER_SIZE_RAW='\x00\x00\x00\x00\x00\x10\x00\x00'

UNKNOWN_A='\x01'
UNKNOWN_B='\x01'
UNKNOWN_C='\x00\x00\x00\x00\x00\x00\x00\x01\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x28\x8F\x18\x00'

# 0=nao
# 1=romeo
# 2=pepper
# 3=juliette
ROBOT_KIND='\x00'

# e.g. 2.8.5.11=000200080005000B
VERSION='\x00\x02\x00\x08\x00\x05\x00\x0B'

### SCRIPT SETTINGS

# for dd bs
BLOCK_SIZE=4096

HEADER_SIZE=4096

INSTALLER_OFFSET=$HEADER_SIZE
INSTALLER_SIZE=1048576

IMAGE_OFFSET=$(($INSTALLER_SIZE+$INSTALLER_OFFSET))


### PARAMETERS
if [ "$#" -ne 2 ]; then
    echo "Illegal number of parameters"
    echo "Usage: $0 image.ext3 image.opn"
    exit 1
fi

IMAGE="$1"
OPN="$2"

# compress filesystem
if [ "$IMAGE" -nt "$IMAGE.gz" ]; then
    echo "Compress filesystem..."
    pigz -kf9 "$IMAGE"
    echo "Done!"
fi

echo "Generate image..."

# generate image header
echo "$MAGIC_NUMBER" | dd of="$2" bs=8
printf "%b" "$FLAGS" | dd of="$2" seek=1 bs=8 conv=notrunc
printf "%b" "$UNKNOWN_A" | dd of="$2" seek=95 bs=1 conv=notrunc
printf "%b" "$INSTALLER_SIZE_RAW" | dd of="$2" seek=12 bs=8 conv=notrunc
printf "%b" "$UNKNOWN_B" | dd of="$2" seek=168 bs=1 conv=notrunc
printf "%b" "$ROBOT_KIND" | dd of="$2" seek=169 bs=1 conv=notrunc
printf "%b" "$UNKNOWN_C" | dd of="$2" seek=170 bs=1 conv=notrunc
printf "%b" "$VERSION" | dd of="$2" seek=24 bs=8 conv=notrunc

# calculate image sizes for installer.sh
IMAGE_CMP_SIZE=$(( $(stat -c %s "$IMAGE.gz") / 1024 ))
IMAGE_CMP_REM=$(( $(stat -c %s "$IMAGE.gz") % 1024 ))
if [ "$IMAGE_CMP_REM" -gt 0 ]; then
    IMAGE_CMP_SIZE=$(( $IMAGE_CMP_SIZE + 1 ))
    dd if=/dev/zero of="$IMAGE.gz" bs=1 count=$(( 1024 - $IMAGE_CMP_REM )) oflag=append conv=notrunc
fi
IMAGE_RAW_SIZE=$(( $(stat -c %s "$IMAGE") / 1024 ))

# update constants in installer.sh
sed -i "s#IMAGE_CMP_SIZE=\".*\"#IMAGE_CMP_SIZE=\"$IMAGE_CMP_SIZE\"#" ./opn/installer.sh
sed -i "s#IMAGE_RAW_SIZE=\".*\"#IMAGE_RAW_SIZE=\"$IMAGE_RAW_SIZE\"#" ./opn/installer.sh

# copy data
dd if=./opn/installer.sh of="$2" seek=$(($INSTALLER_OFFSET/$BLOCK_SIZE)) count=$(($INSTALLER_SIZE/$BLOCK_SIZE)) bs=$BLOCK_SIZE conv=notrunc
dd if="$IMAGE.gz" of="$2" seek=$(($IMAGE_OFFSET/$BLOCK_SIZE)) bs=$BLOCK_SIZE conv=notrunc

# generate sha256 checksums
INSTALLER_CHECKSUM=$(dd if="$2" skip=$(($INSTALLER_OFFSET/$BLOCK_SIZE)) bs=$BLOCK_SIZE count=$(($INSTALLER_SIZE/$BLOCK_SIZE)) | sha256sum | cut -f1 -d\ )
echo "Installer sha256: $INSTALLER_CHECKSUM"
echo $INSTALLER_CHECKSUM | xxd -r -p | dd of="$2" seek=13 bs=8 conv=notrunc

IMAGE_CHECKSUM=$(dd if="$2" skip=$(($IMAGE_OFFSET/$BLOCK_SIZE)) bs=$BLOCK_SIZE | sha256sum | cut -f1 -d\ )
echo "Image sha256: $IMAGE_CHECKSUM"
echo $IMAGE_CHECKSUM | xxd -r -p | dd of="$2" seek=17 bs=8 conv=notrunc

HEADER_CHECKSUM=$(dd if="$2" skip=7 bs=8 count=505 | sha256sum | cut -f1 -d\ )
echo "Header sha256: $HEADER_CHECKSUM"
echo $HEADER_CHECKSUM | xxd -r -p | dd of="$2" seek=3 bs=8 conv=notrunc

echo "Done!"
