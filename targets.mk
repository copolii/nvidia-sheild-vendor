#
# Generate ramdisk images for simulation
#
sim-image: nvidia-tests
	device/nvidia/common/generate_full_filesystem.sh
