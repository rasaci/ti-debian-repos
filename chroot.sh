#!/bin/bash -e

readonly FILE_SCRIPT="$(basename "$0")"
readonly DIR_SCRIPT="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

help() {
    echo
    echo "Usage: ${FILE_SCRIPT} <options>"
    echo
    echo " required:"
    echo " -r --rootfs_base	Debian ROOTFS_BASE Directory (May also be exported to environment)"
    echo
    echo "Example:"
    echo "${FILE_SCRIPT} -r ~/git/varigit/bsps/debian-bullseye/debian_imx8qm-var-som/rootfs"
    echo
    exit
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                help
            ;;
            -r|--rootfs_base)
                ROOTFS_BASE="$2"
                shift # past argument
                shift # past value
            ;;
            -c|--command)
                COMMAND="$2"
                shift # past argument
                shift # past value
            ;;
            *)    # unknown option
                echo "Unknown option: $1"
                help
            ;;
        esac
    done
}

parse_args "$@"

if [ -z "${ROOTFS_BASE}" ]; then
	help
fi
if [ ! -d "${ROOTFS_BASE}" ]; then
	echo "Error, rootfs directory not found ${ROOTFS_BASE}"
	help
fi

# Mount Points
mount_dirs=("/proc" "/dev" "/dev/pts" "/sys" )

chroot_prepare() {

	sudo cp /usr/bin/qemu-aarch64-static ${ROOTFS_BASE}/usr/bin/qemu-aarch64-static

	# Loop through array, mounting directories
	for i in ${!mount_dirs[@]}; do
		mount_dir=${mount_dirs[$i]}
		MOUNT_CMD="sudo mount -o bind ${mount_dir} ${ROOTFS_BASE}${mount_dir}"
		echo "${MOUNT_CMD}"
		${MOUNT_CMD}
	done

    sudo mkdir -p ${ROOTFS_BASE}/workdir
    sudo mount -o bind ${DIR_SCRIPT} ${ROOTFS_BASE}/workdir
}

chroot_cleanup() {
	# Loop through array, unmounting directories
	for ((i=${#mount_dirs[@]}-1; i>=0; i--)); do
		mount_dir=${mount_dirs[$i]}
		MOUNT_CMD="sudo umount ${ROOTFS_BASE}${mount_dir}"
		echo "${MOUNT_CMD}"
		${MOUNT_CMD}
	done

    sudo umount ${ROOTFS_BASE}/workdir

}

# Set up the trap command to run the cleanup function
trap 'chroot_cleanup EXIT' EXIT

# Make sure not already mounted
if [ -n "$(mount | grep -i "${ROOTFS_BASE}")" ]; then
    echo "Error, ${ROOTFS_BASE} is already mounted"
    set +e
    chroot_cleanup
    exit -1
fi

chroot_prepare

if [ -n "${COMMAND}" ]; then
    sudo chroot ${ROOTFS_BASE}/ /bin/bash -c "${COMMAND}"
else
    sudo chroot ${ROOTFS_BASE}/ /bin/bash
fi

sleep 0.5
