#!/bin/bash

set -e
set -o pipefail

### IMAGE SETTINGS

MAGIC_NUMBER="ALDIMAGE"

# e.g. 2.8.5.11=000200080005000B
VERSION='\x00\x02\x00\x08\x00\x05\x00\x0B'

### SCRIPT SETTINGS

# for dd bs
BLOCK_SIZE=1024

HEADER_SIZE=4096
INSTALLER_OFFSET=$HEADER_SIZE

INSTALLER_PATH="installer.sh"


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

# calculate installer.sh size
INSTALLER_SIZE_KB=$(( $(stat -c %s "$INSTALLER_PATH") / 1024 ))
INSTALLER_REM=$(( $(stat -c %s "$INSTALLER_PATH") % 1024 ))
if [ "$INSTALLER_REM" -gt 0 ]; then
    INSTALLER_SIZE_KB=$(( $INSTALLER_SIZE_KB + 1 ))
fi
INSTALLER_SIZE_B=$(( $INSTALLER_SIZE_KB * 1024 ))


echo "Generate image..."

# generate image header
echo -n "$MAGIC_NUMBER"                        | dd of="$OPN" seek=$((0x0000 / 8)) bs=8
                                                                    # 0x0018 SHA256 header (0x0038-0x0FFF, filled below)
printf "%016x" "$INSTALLER_SIZE_B" | xxd -r -p | dd of="$OPN" seek=$((0x0060 / 8)) bs=8 conv=notrunc
                                                                    # 0x0068 SHA256 installer (filled below)
printf "%b" "$VERSION"                         | dd of="$OPN" seek=$((0x00C0 / 8)) bs=8 conv=notrunc

# copy installer
dd if=$INSTALLER_PATH of="$OPN" seek=$(($INSTALLER_OFFSET/$BLOCK_SIZE)) bs=$BLOCK_SIZE conv=notrunc

# copy filesystem
IMAGE_OFFSET=$(($INSTALLER_SIZE_B+$INSTALLER_OFFSET))
dd if="$IMAGE.gz" of="$OPN" seek=$(($IMAGE_OFFSET/$BLOCK_SIZE)) bs=$BLOCK_SIZE conv=notrunc

# generate checksum
INSTALLER_CHECKSUM=$(dd if="$OPN" skip=$(($INSTALLER_OFFSET/$BLOCK_SIZE)) bs=$BLOCK_SIZE count=$(($INSTALLER_SIZE_B/$BLOCK_SIZE)) | sha256sum | cut -f1 -d\ )
echo "Installer sha256: $INSTALLER_CHECKSUM"
echo "$INSTALLER_CHECKSUM" | xxd -r -p | dd of="$OPN" seek=$((0x0068 / 8)) bs=8 conv=notrunc

HEADER_CHECKSUM=$(dd if="$OPN" skip=$((0x0038 / 8)) bs=8 count=$(( ($HEADER_SIZE - 0x0038) / 8 )) | sha256sum | cut -f1 -d\ )
echo "Header sha256: $HEADER_CHECKSUM"
echo "$HEADER_CHECKSUM" | xxd -r -p | dd of="$OPN" seek=$((0x0018 / 8)) bs=8 conv=notrunc

# fill 1024 byte blocks
FILE_SIZE=$(stat -c %s "$OPN")
FILE_SIZE_REM=$(( $FILE_SIZE % 1024 ))
if [ "$FILE_SIZE_REM" -gt 0 ]; then
    dd if=/dev/zero of="$OPN" oflag=append conv=notrunc bs=1 count=$(( 1024 - $FILE_SIZE_REM ))
fi

echo "Done!"
