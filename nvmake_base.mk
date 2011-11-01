ifneq ($(filter-out SHARED_LIBRARIES EXECUTABLES,$(LOCAL_MODULE_CLASS)),)
$(error The integration layer for the nvmake build system supports only shared libraries and executables)
endif

include $(NVIDIA_BASE)
# TODO Enable coverage build

ifeq ($(LOCAL_NVIDIA_NVMAKE_OVERRIDE_BUILD_TYPE),)
  NVIDIA_NVMAKE_BUILD_TYPE := $(TARGET_BUILD_TYPE)
else
  NVIDIA_NVMAKE_BUILD_TYPE := $(LOCAL_NVIDIA_NVMAKE_OVERRIDE_BUILD_TYPE)
endif

ifeq ($(LOCAL_NVIDIA_NVMAKE_OVERRIDE_MODULE_NAME),)
  NVIDIA_NVMAKE_MODULE_NAME := $(LOCAL_MODULE)
else
  NVIDIA_NVMAKE_MODULE_NAME := $(LOCAL_NVIDIA_NVMAKE_OVERRIDE_MODULE_NAME)
endif


ifeq ($(LOCAL_NVIDIA_NVMAKE_OVERRIDE_TOP),)
  NVIDIA_NVMAKE_TOP := $(TEGRA_TOP)/gpu/$(LOCAL_NVIDIA_NVMAKE_TREE)
else
  NVIDIA_NVMAKE_TOP := $(LOCAL_NVIDIA_NVMAKE_OVERRIDE_TOP)
endif

NVIDIA_NVMAKE_MODULE := $(NVIDIA_NVMAKE_TOP)/$(LOCAL_NVIDIA_NVMAKE_BUILD_DIR)/_out/Android_ARMv7_$(NVIDIA_NVMAKE_BUILD_TYPE)/$(NVIDIA_NVMAKE_MODULE_NAME)$(LOCAL_MODULE_SUFFIX)

ifneq ($(strip $(SHOW_COMMANDS)),)
  NVIDIA_NVMAKE_VERBOSE := NV_VERBOSE=1
else
  NVIDIA_NVMAKE_VERBOSE := -s
endif

#
# Call into the nvmake build system to build the module
#

$(NVIDIA_NVMAKE_MODULE) $(LOCAL_MODULE)_nvmakeclean: NVIDIA_NVMAKE_COMMAND := $(MAKE) \
    MAKE=$(shell which $(MAKE)) \
    NV_ANDROID_TOOLS=$(P4ROOT)/sw/mobile/tools/linux/android/nvmake \
    NV_UNIX_BUILD_CHROOT=$(P4ROOT)/sw/tools/unix/hosts/Linux-x86/unix-build \
    NV_SOURCE=$(NVIDIA_NVMAKE_TOP) \
    NV_TOOLS=$(P4ROOT)/sw/tools \
    NV_HOST_OS=Linux \
    NV_HOST_ARCH=x86 \
    NV_TARGET_OS=Android \
    NV_TARGET_ARCH=ARMv7 \
    NV_BUILD_TYPE=$(NVIDIA_NVMAKE_BUILD_TYPE) \
    $(NVIDIA_NVMAKE_VERBOSE) \
    -C $(NVIDIA_NVMAKE_TOP)/$(LOCAL_NVIDIA_NVMAKE_BUILD_DIR) \
    -f makefile.nvmk \
    $(LOCAL_NVIDIA_NVMAKE_ARGS)

# This target needs to be forced, nvmake will do its own dependency checking
$(NVIDIA_NVMAKE_MODULE): $(LOCAL_ADDITIONAL_DEPENDENCIES) FORCE
	@echo "Build with nvmake: $(PRIVATE_MODULE) ($@)"
	+$(hide) $(NVIDIA_NVMAKE_COMMAND)

$(LOCAL_MODULE)_nvmakeclean:
	@echo "Clean nvmake build files: $(PRIVATE_MODULE)"
	+$(hide) $(NVIDIA_NVMAKE_COMMAND) clobber

.PHONY: $(LOCAL_MODULE)_nvmakeclean


#
# Bring module from the nvmake build output, and apply the usual
# processing for shared library or executable.
# Also make the module's clean target descend into nvmake.
#

include $(BUILD_SYSTEM)/dynamic_binary.mk

$(linked_module): $(NVIDIA_NVMAKE_MODULE) | $(ACP)
	@echo "Copy from nvmake output: $(PRIVATE_MODULE) ($@)"
	$(copy-file-to-target)

$(cleantarget):: $(LOCAL_MODULE)_nvmakeclean

NVIDIA_NVMAKE_BUILD_TYPE :=
NVIDIA_NVMAKE_TOP :=
NVIDIA_NVMAKE_MODULE :=
NVIDIA_NVMAKE_MODULE_NAME :=
NVIDIA_NVMAKE_VERBOSE :=

