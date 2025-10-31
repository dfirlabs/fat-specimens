#!/bin/bash
#
# Script to generate fat12, fat16 and fat32 test files
# Requires Linux with dd and mkfs.fat

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

# Creates test file entries.
#
# Arguments:
#   a string containing the mount point of the image file
#
create_test_file_entries()
{
	MOUNT_POINT=$1;

	# Create an empty file
	touch ${MOUNT_POINT}/emptyfile

	# Create a directory
	mkdir ${MOUNT_POINT}/testdir1

	# Create a file that can be stored as inline data
	echo "My file" > ${MOUNT_POINT}/testdir1/testfile1

	# Create a file that cannot be stored as inline data
	cp LICENSE ${MOUNT_POINT}/testdir1/TestFile2

	# Create a file with a long filename
	touch "${MOUNT_POINT}/testdir1/My long, very long file name, so very long"

	# Create a file with a filename with the maximum length
	FILENAME=`printf "l%.0s" {1..255}`
	touch "${MOUNT_POINT}/testdir1/${FILENAME}"

	# Create a file with a filename that exceeds the maximum length
	# touch: cannot touch 'l...l': File name too long
	# FILENAME=`printf "l%.0s" {1..256}`
	# touch "${MOUNT_POINT}/testdir1/${FILENAME}"

	# Create a file with a filename that contains a dot.
	touch "${MOUNT_POINT}/testdir1/te.st3.txt"

	# Create a file with a control code in the filename
	# touch `printf "${MOUNT_POINT}/control_cod\x03"`
	# touch: cannot touch 'control_cod'$'\003': Invalid argument

	# Create a file with a filename that starts with a \xe5 character
	# touch `printf "${MOUNT_POINT}/\xe5special"`
	# touch: cannot touch ''$'\345''special': Invalid argument
	# touch `printf "${MOUNT_POINT}/\xc3\xa5special"`
	# touch: cannot touch 'åspecial': Invalid argument

	# Create a file with an UTF-8 NFC encoded filename
	# touch `printf "${MOUNT_POINT}/nfc_t\xc3\xa9stfil\xc3\xa8"`
	# touch: cannot touch 'nfc_téstfilè': Invalid argument

	# Create a hard link
	# ln: failed to create hard link: Operation not permitted

	# Create a symbolic link
	# ln: failed to create symbolic link: Operation not permitted

	# Create a file entry with an UTF-8 encoded filename
	# touch: setting times of: No such file or directory

	# Create a file entry with an extended attribute
	# setfattr: Operation not supported
}

# Creates a test image file.
#
# Arguments:
#   a string containing the path of the image file
#   an integer containing the size of the image file
#   an integer containing the sector size
#   an array containing the arguments for mkfs.fat
#
create_test_image_file()
{
	IMAGE_FILE=$1;
	IMAGE_SIZE=$2;
	SECTOR_SIZE=$3;
	shift 3;
	local ARGUMENTS=("$@");

	dd if=/dev/zero of=${IMAGE_FILE} bs=${SECTOR_SIZE} count=$(( ${IMAGE_SIZE} / ${SECTOR_SIZE} )) 2> /dev/null;

	echo "mkfs.fat ${ARGUMENTS[@]} ${IMAGE_FILE}";
	mkfs.fat ${ARGUMENTS[@]} ${IMAGE_FILE};
}

# Creates a test image file with file entries.
#
# Arguments:
#   a string containing the path of the image file
#   an integer containing the size of the image file
#   an integer containing the sector size
#   an array containing the arguments for mkfs.fat
#
create_test_image_file_with_file_entries()
{
	IMAGE_FILE=$1;
	IMAGE_SIZE=$2;
	SECTOR_SIZE=$3;
	shift 3;
	local ARGUMENTS=("$@");

	create_test_image_file ${IMAGE_FILE} ${IMAGE_SIZE} ${SECTOR_SIZE} ${ARGUMENTS[@]};

	CURRENT_GID=$( id -g );
	CURRENT_UID=$( id -u );
	sudo mount -o loop,rw,gid=${CURRENT_GID},uid=${CURRENT_UID} ${IMAGE_FILE} ${MOUNT_POINT};

	create_test_file_entries ${MOUNT_POINT};

	sudo umount ${MOUNT_POINT};
}

assert_availability_binary dd;
assert_availability_binary fallocate;
assert_availability_binary mkfs.fat;

SPECIMENS_PATH="specimens/mkfs.fat";

if test -d ${SPECIMENS_PATH};
then
	echo "Specimens directory: ${SPECIMENS_PATH} already exists.";

	exit ${EXIT_FAILURE};
fi

mkdir -p ${SPECIMENS_PATH};

set -e;

MOUNT_POINT="/mnt/fat";

sudo mkdir -p ${MOUNT_POINT};

SECTOR_SIZE=512;

# Create a FAT-12 file system
IMAGE_SIZE=$(( 4096 * 1024 ));

create_test_image_file_with_file_entries "${SPECIMENS_PATH}/fat12.raw" ${IMAGE_SIZE} ${SECTOR_SIZE} "-F 12" "-n FAT12_TEST";

# Create a FAT-16 file system
IMAGE_SIZE=$(( 16 * 1024 * 1024 ));

create_test_image_file_with_file_entries "${SPECIMENS_PATH}/fat16.raw" ${IMAGE_SIZE} ${SECTOR_SIZE} "-F 16" "-n FAT16_TEST";

# Create a FAT-32 file system
IMAGE_SIZE=$(( 64 * 1024 * 1024 ));

create_test_image_file_with_file_entries "${SPECIMENS_PATH}/fat32.raw" ${IMAGE_SIZE} ${SECTOR_SIZE} "-F 32" "-n FAT32_TEST";

# Create FAT file systems with specific cluster (block) sizes.
for CLUSTER_SIZE in 1 2 4 8 16 32 64 128;
do
	# Minimum number of clusters required for a FAT-32 is 65527
	IMAGE_SIZE=$(( ( ( 65527 * ${CLUSTER_SIZE} ) * 512 ) + ( 4096 * 1024 ) ));
	IMAGE_SIZE=$(( ${IMAGE_SIZE} / 1024 ));
	IMAGE_SIZE=$(( ${IMAGE_SIZE} * 1024 ));

	create_test_image_file_with_file_entries "${SPECIMENS_PATH}/fat32_cluster_${CLUSTER_SIZE}.raw" ${IMAGE_SIZE} ${SECTOR_SIZE} "-F 32" "-n FAT32_TEST" "-s ${CLUSTER_SIZE}" "-S 512";
done

# Create FAT file systems with specific bytes per sector.
for SECTOR_SIZE in 512 1024 2048 4096;
do
	# Minimum number of clusters required for a FAT-32 is 65527
	IMAGE_SIZE=$(( ( 65527 * ${SECTOR_SIZE} ) + ( 4096 * 1024 ) ));
	IMAGE_SIZE=$(( ${IMAGE_SIZE} / 1024 ));
	IMAGE_SIZE=$(( ${IMAGE_SIZE} * 1024 ));

	create_test_image_file_with_file_entries "${SPECIMENS_PATH}/fat32_sector_${SECTOR_SIZE}.raw" ${IMAGE_SIZE} ${SECTOR_SIZE} "-F 32" "-n FAT32_TEST" "-s 1" "-S ${SECTOR_SIZE}";
done

# Note that Linux cannot mount a FAT file system with sector size >= 8192
for SECTOR_SIZE in 8192 16384 32768;
do
	# Minimum number of clusters required for a FAT-32 is 65527
	IMAGE_SIZE=$(( ( 65527 * ${SECTOR_SIZE} ) + ( 4096 * 1024 ) ));
	IMAGE_SIZE=$(( ${IMAGE_SIZE} / 1024 ));
	IMAGE_SIZE=$(( ${IMAGE_SIZE} * 1024 ));

	create_test_image_file "${SPECIMENS_PATH}/fat32_sector_${SECTOR_SIZE}.raw" ${IMAGE_SIZE} ${SECTOR_SIZE} "-F 32" "-n FAT32_TEST" "-s 1" "-S ${SECTOR_SIZE}";
done

# TODO: Create an image that is unaligned -a
# TODO: Create an image that is has a backup boot sector elsewhere than sector 6 (default) -b
# TODO: Create an image with different number of FATs -f
# TODO: Create an image with different number root directory entries -r
# TODO: Create Atari variation -A or --variant=atari

# TODO: Create an image with OEM codepage --codepage
# TODO: https://www.kernel.org/doc/html/v5.8/filesystems/vfat.html

exit ${EXIT_SUCCESS};

