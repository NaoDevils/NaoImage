#!/bin/bash

set -e
set -o pipefail

usage() { echo "Usage: $0 -i <nao-image.opn> [-f <framework directory>] [-r <root@naoip>]" 1>&2; exit 1; }

while getopts "i:f:r:" o; do
    case "${o}" in
        i)
            INPUT_OPN="${OPTARG}"
            ;;
        f)
            FRAMEWORK_DIR="${OPTARG%/}"
            ;;
        r)
            SSH="${OPTARG}"
            ;;
        *)
            usage
            ;;
    esac
done

if [ -z "$INPUT_OPN" ]; then
	usage
fi

if [ -z "$FRAMEWORK_DIR" ]; then
	rm -rf ./root.tgz
	./generate_image.sh "$INPUT_OPN" "image.ext3" ubuntu naodevils-framework-base joystick save-base
	
	GIT_FRAMEWORK="baseonly"
else
	export FRAMEWORK_DIR="$FRAMEWORK_DIR"
	export DHCP=false

	./generate_image.sh "$INPUT_OPN" "image.ext3" ubuntu naodevils-framework-base joystick save-base naodevils-robotconfig naodevils-framework-copy
	
	GIT_FRAMEWORK="$(git -C "$FRAMEWORK_DIR" rev-parse --short HEAD)"
fi

GIT_IMAGE="$(git rev-parse --short HEAD)"
DATE="$(date +%Y%m%d_%H%M%S)"
./generate_opn.sh "image.ext3" "naodevils_${DATE}_${GIT_FRAMEWORK}_${GIT_IMAGE}.opn"

if ! [ -z "$SSH" ]; then
    ./flash_robot.sh "naodevils_${DATE}_${GIT_FRAMEWORK}_${GIT_IMAGE}.opn" "$SSH"
fi
