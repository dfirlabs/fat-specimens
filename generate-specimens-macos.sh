#!/bin/bash
#
# Script to generate FAT-12, FAT-16, FAT-32 and ExFAT test files
# Requires macOS

EXIT_SUCCESS=0
EXIT_FAILURE=1

# Checks the availability of a binary and exits if not available.
#
# Arguments:
#   a string containing the name of the binary
#
assert_availability_binary()
{
	local BINARY=$1

	which ${BINARY} > /dev/null 2>&1
	if test $? -ne ${EXIT_SUCCESS}
	then
		echo "Missing binary: ${BINARY}"
		echo ""

		exit ${EXIT_FAILURE}
	fi
}

assert_availability_binary hdiutil
assert_availability_binary sw_vers

MACOS_VERSION=`sw_vers -productVersion`
SHORT_VERSION=`echo "${MACOS_VERSION}" | sed 's/^\([0-9][0-9]*[.][0-9][0-9]*\).*$/\1/'`
MAJOR_VERSION=`echo "${MACOS_VERSION}" | sed 's/^\([0-9][0-9]*\).*$/\1/'`

# Note that versions of Mac OS before 10.13 do not support "sort -V"
MAXIMUM_VERSION=`echo "${MAJOR_VERSION} 10" | tr ' ' '\n' | sed 's/[.]//' | sort -rn | head -n 1`

if test "${MAXIMUM_VERSION}" == "10"
then
	MINIMUM_VERSION=`echo "${SHORT_VERSION} 10.13" | tr ' ' '\n' | sed 's/[.]//' | sort -n | head -n 1`

	if test "${MINIMUM_VERSION}" != "1013"
	then
		echo "Unsupported MacOS version: ${MACOS_VERSION}"

		exit ${EXIT_FAILURE}
	fi
fi

SPECIMENS_PATH="specimens/${MACOS_VERSION}"

if test -d ${SPECIMENS_PATH}
then
	echo "Specimens directory: ${SPECIMENS_PATH} already exists."

	exit ${EXIT_FAILURE}
fi

mkdir -p ${SPECIMENS_PATH}

set -e

echo "Creating: FAT-12"
hdiutil create -fs 'MS-DOS FAT12' -size "4M" -type UDIF "${SPECIMENS_PATH}/fat12"

echo "Creating: FAT-16"
hdiutil create -fs 'MS-DOS FAT16' -size "16M" -type UDIF "${SPECIMENS_PATH}/fat16"

echo "Creating: FAT-32"
hdiutil create -fs 'MS-DOS FAT32' -size "64M" -type UDIF "${SPECIMENS_PATH}/fat32"

echo "Creating: ExFAT"
hdiutil create -fs 'ExFAT' -size "4M" -type UDIF "${SPECIMENS_PATH}/exfat"

exit ${EXIT_SUCCESS}
