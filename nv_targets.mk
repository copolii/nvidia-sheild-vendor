#
# Nvidia specific targets
#

.PHONY: dev nv-blob sim-image

dev: droidcore target-files-package
ifneq ($(NO_ROOT_DEVICE),)
ifeq ($(TARGET_BOARD_PLATFORM_TYPE),simulation)
	device/nvidia/common/generate_full_filesystem.sh
else
	device/nvidia/common/generate_nvtest_ramdisk.sh $(TARGET_PRODUCT) $(TARGET_BUILD_TYPE)
	device/nvidia/common/generate_qt_ramdisk.sh $(TARGET_PRODUCT) $(TARGET_BUILD_TYPE)
endif
endif

# generate blob for bootloaders
nv-blob: \
      $(HOST_OUT_EXECUTABLES)/nvblob \
      $(HOST_OUT_EXECUTABLES)/nvsignblob \
      $(TOP)/device/nvidia/common/security/signkey.pk8 \
      $(PRODUCT_OUT)/bootloader.bin \
      $(PRODUCT_OUT)/microboot.bin
	$(hide) python $(filter %nvblob,$^) \
		$(filter %bootloader.bin,$^) EBT 1 \
		$(filter %microboot.bin,$^) NVC 1

#
# Generate ramdisk images for simulation
#
sim-image: nvidia-tests
	device/nvidia/common/copy_simtools.sh
	device/nvidia/common/generate_full_filesystem.sh
