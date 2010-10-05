LOCAL_PATH := $(call my-dir)

include $(CLEAR_VARS)

PRODUCT_COPY_FILES += $(LOCAL_PATH)/$(TARGET_DEVICE)/nvflash:../../../host/linux-x86/bin/$(TARGET_DEVICE)/nvflash
PRODUCT_COPY_FILES += $(LOCAL_PATH)/$(TARGET_DEVICE)/bootloader.bin:bootloader.bin
PRODUCT_COPY_FILES += $(LOCAL_PATH)/$(TARGET_DEVICE)/flash.cfg:flash.cfg
PRODUCT_COPY_FILES += $(LOCAL_PATH)/$(TARGET_DEVICE)/flash.bct:flash.bct
