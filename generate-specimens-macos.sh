#!/bin/bash
#
# Script to generate FAT12, FAT16, FAT32 and ExFAT test files
# Requires macOS

EXIT_SUCCESS=0;
EXIT_FAILURE=1;

# Checks the availability of a binary and exits if not available.
#
# Arguments:
#   a string containing the name of the binary
#
assert_availability_binary()
{
	local BINARY=$1;

	which ${BINARY} > /dev/null 2>&1;
	if test $? -ne ${EXIT_SUCCESS};
	then
		echo "Missing binary: ${BINARY}";
		echo "";

		exit ${EXIT_FAILURE};
	fi
}

assert_availability_binary diskutil;
assert_availability_binary hdiutil;
assert_availability_binary sw_vers;

MACOS_VERSION=`sw_vers -productVersion`;

MINIMUM_VERSION=`echo "${MACOS_VERSION} 10.13" | tr ' ' '\n' | sort -V | head -n 1`;

if test "${MINIMUM_VERSION}" != "10.13";
then
	echo "Unsupported MacOS version: ${MACOS_VERSION}";

	exit ${EXIT_FAILURE};
fi

SPECIMENS_PATH="specimens/${MACOS_VERSION}";

if test -d ${SPECIMENS_PATH};
then
	echo "Specimens directory: ${SPECIMENS_PATH} already exists.";

	exit ${EXIT_FAILURE};
fi

mkdir -p ${SPECIMENS_PATH};

set -e;

DEVICE_NUMBER=`diskutil list | grep -e '^/dev/disk' | tail -n 1 | sed 's?^/dev/disk??;s? .*$??'`;

VOLUME_DEVICE_NUMBER=$(( ${DEVICE_NUMBER} + 1 ));

# Create raw disk image with a FAT12 file system
IMAGE_NAME="fat12";
IMAGE_SIZE="4M";

hdiutil create -fs 'MS-DOS FAT12' -size ${IMAGE_SIZE} -type UDIF ${SPECIMENS_PATH}/${IMAGE_NAME};

# Create raw disk image with a FAT16 file system
IMAGE_NAME="fat16";
IMAGE_SIZE="4M";

hdiutil create -fs 'MS-DOS FAT16' -size ${IMAGE_SIZE} -type UDIF ${SPECIMENS_PATH}/${IMAGE_NAME};

# Create raw disk image with a FAT32 file system
IMAGE_NAME="fat32";
IMAGE_SIZE="4M";

hdiutil create -fs 'MS-DOS FAT32' -size ${IMAGE_SIZE} -type UDIF ${SPECIMENS_PATH}/${IMAGE_NAME};

# Create raw disk image with a ExFAT file system
IMAGE_NAME="exfat";
IMAGE_SIZE="4M";

hdiutil create -fs 'ExFAT' -size ${IMAGE_SIZE} -type UDIF ${SPECIMENS_PATH}/${IMAGE_NAME};

exit ${EXIT_SUCCESS};

