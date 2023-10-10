#!/bin/sh

# enable terminal receiver
stty cread

set -eux

DEST_PART="${1}"
USER_PART="${2}"
IMAGE_FILE="${3}"

INSTALLER_SIZE=$(hexdump -s96 -n8 -v -e '8/1 "%02x"' "${IMAGE_FILE}")
INSTALLER_SIZE=$(printf "%d" "0x${INSTALLER_SIZE}")
IMAGE_OFFSET=$(( $INSTALLER_SIZE + 0x1000 ))

echo "Press any key to open shell"
if read -t1 -n1 -s -r; then
    /bin/sh
fi

setears --state PROGRESS 10

echo "Start flashing"

(
    set -euxo pipefail
    
    # dd returns a non-zero exit status if gunzip closes the pipe when data is complete.
    # Ignore this error here and only fail on gunzip error.
    ( dd if="${IMAGE_FILE}" bs=1024 skip="$((IMAGE_OFFSET / 1024))" || true ) | gunzip -c | dd of="${DEST_PART}" bs=4096
)

if [ $? -eq 0 ]; then
    setears --state PROGRESS 50
else
    echo "Flashing failed!"
    
    # Do not boot corrupt filesystem
    wipefs -a "${DEST_PART}"
    
    # An error occured, set ears to blinking state.
    # The setears binary does not return.
    setears --state UPGRADE_POSTCHECK
    halt -f
    exit 1
fi


MOUNTS=$(mount | grep '^/dev' | cut -d' ' -f3)
[ -n "${MOUNTS}" ] && (umount -fr "${MOUNTS}" && sync && sleep 2)

# clean data
wipefs -a "${USER_PART}"

echo "Done!"

setears --state PROGRESS 100

echo "Press any key to open shell"
if read -t1 -n1 -s -r; then
    /bin/sh
    
    MOUNTS=$(mount | grep '^/dev' | cut -d' ' -f3)
    [ -n "${MOUNTS}" ] && umount -fr "${MOUNTS}"
fi

echo "Reboot"

sync
sleep 2

chest-ctl --reset
halt -f

exit 0
