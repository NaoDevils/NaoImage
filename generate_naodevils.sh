#!/bin/bash

set -e
set -o pipefail

if [ "$#" -eq 0 ]; then
    echo "Illegal number of parameters"
    echo "Usage: $0 nao-image.opn [root@naoip]"
    exit 1
fi

INPUT_OPN="$1"
SSH="$2"

export FRAMEWORK_DIR=../NDevils2015/
export DHCP=false

./generate_image.sh "$INPUT_OPN" "image.ext3" ubuntu opencl naodevils-framework-base save-base naodevils-robotconfig naodevils-framework-copy

GIT_IMAGE="$(git rev-parse --short HEAD)"
GIT_FRAMEWORK="$(git -C "$FRAMEWORK_DIR" rev-parse --short HEAD)"
DATE="$(date +%Y%m%d_%H%M%S)"
./generate_opn.sh "image.ext3" "naodevils_${DATE}_${GIT_FRAMEWORK}_${GIT_IMAGE}.opn"

if [ "$#" -eq 2 ]; then
    ./flash_robot.sh "naodevils_${DATE}_${GIT_FRAMEWORK}_${GIT_IMAGE}.opn" "$SSH"
fi
