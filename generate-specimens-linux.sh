#!/bin/bash
#
# Script to generate FAT-12, FAT-16 and FAT-32 test files
# Requires Linux with dd and mkfs.fat

source ./shared_linux.sh

assert_availability_binary dd
assert_availability_binary fallocate
assert_availability_binary mkfs.fat

VERSION=$( mkfs.fat --help 2>/dev/null | head -n 1 | sed 's/mkfs.fat \(\S*\) .*$/\1/' )

SPECIMENS_PATH="specimens/mkfs.fat-${VERSION}"

if test -d ${SPECIMENS_PATH}
then
	echo "Specimens directory: ${SPECIMENS_PATH} already exists."

	exit ${EXIT_FAILURE}
fi

mkdir -p ${SPECIMENS_PATH}

set -e

MOUNT_POINT="/mnt/fat"

sudo mkdir -p ${MOUNT_POINT}

SECTOR_SIZE=512

echo "Creating: FAT-12"
create_test_image_file_with_file_entries "${SPECIMENS_PATH}/fat12.raw" $(( 4096 * 1024 )) ${SECTOR_SIZE} "-F 12" "-n FAT12_TEST"

echo "Creating: FAT-16"
create_test_image_file_with_file_entries "${SPECIMENS_PATH}/fat16.raw" $(( 16 * 1024 * 1024 )) ${SECTOR_SIZE} "-F 16" "-n FAT16_TEST"

echo "Creating: FAT-32"
create_test_image_file_with_file_entries "${SPECIMENS_PATH}/fat32.raw" $(( 64 * 1024 * 1024 )) ${SECTOR_SIZE} "-F 32" "-n FAT32_TEST"

for CLUSTER_SIZE in 1 2 4 8 16 32 64 128
do
	# Minimum number of clusters required for a FAT-32 is 65527
	IMAGE_SIZE=$(( ( ( 65527 * ${CLUSTER_SIZE} ) * 512 ) + ( 4096 * 1024 ) ))
	IMAGE_SIZE=$(( ${IMAGE_SIZE} / 1024 ))
	IMAGE_SIZE=$(( ${IMAGE_SIZE} * 1024 ))

	echo "Creating: FAT-32; with cluster size: ${CLUSTER_SIZE}"
	create_test_image_file_with_file_entries "${SPECIMENS_PATH}/fat32_cluster_${CLUSTER_SIZE}.raw" ${IMAGE_SIZE} ${SECTOR_SIZE} "-F 32" "-n FAT32_TEST" "-s ${CLUSTER_SIZE}" "-S 512"
done

for SECTOR_SIZE in 512 1024 2048 4096 8192 16384 32768
do
	# Minimum number of clusters required for a FAT-32 is 65527
	IMAGE_SIZE=$(( ( 65527 * ${SECTOR_SIZE} ) + ( 4096 * 1024 ) ))
	IMAGE_SIZE=$(( ${IMAGE_SIZE} / 1024 ))
	IMAGE_SIZE=$(( ${IMAGE_SIZE} * 1024 ))

	echo "Creating: FAT-32; with sector size: ${SECTOR_SIZE}"

	# Note that Linux cannot mount a FAT file system with sector size >= 8192
	if test ${SECTOR_SIZE} -lt 8192
	then
		create_test_image_file_with_file_entries "${SPECIMENS_PATH}/fat32_sector_${SECTOR_SIZE}.raw" ${IMAGE_SIZE} ${SECTOR_SIZE} "-F 32" "-n FAT32_TEST" "-s 1" "-S ${SECTOR_SIZE}"
	else
		create_test_image_file "${SPECIMENS_PATH}/fat32_sector_${SECTOR_SIZE}.raw" ${IMAGE_SIZE} ${SECTOR_SIZE} "-F 32" "-n FAT32_TEST" "-s 1" "-S ${SECTOR_SIZE}"
	fi
done

# TODO: Create an image that is unaligned -a
# TODO: Create an image that is has a backup boot sector elsewhere than sector 6 (default) -b
# TODO: Create an image with different number of FATs -f
# TODO: Create an image with different number root directory entries -r
# TODO: Create Atari variation -A or --variant=atari

# TODO: Create an image with OEM codepage --codepage
# TODO: https://www.kernel.org/doc/html/v5.8/filesystems/vfat.html

exit ${EXIT_SUCCESS}
