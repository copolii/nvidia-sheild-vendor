LOCAL_PATH := $(call my-dir)

include $(CLEAR_VARS)

file := $(HOST_OUT_EXECUTABLES)/nvflash$(HOST_EXECUTABLE_SUFFIX)
ALL_PREBUILT += $(file)
$(file) : $(LOCAL_PATH)/$(notdir $(file)) | $(ACP)
	$(transform-prebuilt-to-target)

PRODUCT_COPY_FILES += $(LOCAL_PATH)/$(TARGET_DEVICE)/bootloader.bin:bootloader.bin
PRODUCT_COPY_FILES += $(LOCAL_PATH)/$(TARGET_DEVICE)/flash.cfg:flash.cfg
PRODUCT_COPY_FILES += $(LOCAL_PATH)/$(TARGET_DEVICE)/flash.bct:flash.bct
