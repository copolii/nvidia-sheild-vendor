LOCAL_PATH := $(call my-dir)

include $(CLEAR_VARS)

ifeq ($(HAVE_NVIDIA_PROP_SRC),false)
file := $(HOST_OUT_EXECUTABLES)/$(TARGET_DEVICE)/nvflash$(HOST_EXECUTABLE_SUFFIX)
ALL_PREBUILT += $(file)
$(file) : $(LOCAL_PATH)/$(TARGET_DEVICE)/$(notdir $(file)) | $(ACP)
	$(transform-prebuilt-to-target)

PRODUCT_COPY_FILES += $(LOCAL_PATH)/$(TARGET_DEVICE)/bootloader.bin:bootloader.bin
PRODUCT_COPY_FILES += $(LOCAL_PATH)/$(TARGET_DEVICE)/flash.cfg:flash.cfg
PRODUCT_COPY_FILES += $(LOCAL_PATH)/$(TARGET_DEVICE)/flash.bct:flash.bct
endif
