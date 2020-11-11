#!/bin/bash

set -e
set -o pipefail

### PARAMETERS
if [ "$#" -ne 2 ]; then
    echo "Illegal number of parameters"
    echo "Usage: $0 image.opn root@naoip"
    exit 1
fi

# detects mount point of data partition automatically
# single line to avoid multiple password / key authentications
cat "$1" | ssh "$2" 'if [ -d /data ]; then DIR=/data; else DIR=/home; fi; mkdir -p $DIR/.image && cat - > $DIR/.image/image.opn && reboot'
