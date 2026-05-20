#!/bin/bash
#
# Shared functionality for scripts to generate FAT-12, FAT-16 and FAT-32 test files

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

# Creates test file entries.
#
# Arguments:
#   a string containing the mount point of the image file
#
create_test_file_entries()
{
	MOUNT_POINT=$1

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
	IMAGE_FILE=$1
	IMAGE_SIZE=$2
	SECTOR_SIZE=$3
	shift 3
	local ARGUMENTS=("$@")

	dd if=/dev/zero of=${IMAGE_FILE} bs=${SECTOR_SIZE} count=$(( ${IMAGE_SIZE} / ${SECTOR_SIZE} )) 2> /dev/null

	mkfs.fat ${ARGUMENTS[@]} ${IMAGE_FILE} > /dev/null
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
	IMAGE_FILE=$1
	IMAGE_SIZE=$2
	SECTOR_SIZE=$3
	shift 3
	local ARGUMENTS=("$@")

	create_test_image_file ${IMAGE_FILE} ${IMAGE_SIZE} ${SECTOR_SIZE} ${ARGUMENTS[@]}

	CURRENT_GID=$( id -g )
	CURRENT_UID=$( id -u )
	sudo mount -o loop,rw,gid=${CURRENT_GID},uid=${CURRENT_UID} ${IMAGE_FILE} ${MOUNT_POINT}

	create_test_file_entries ${MOUNT_POINT}

	sudo umount ${MOUNT_POINT}
}
