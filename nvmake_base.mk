ifneq ($(filter-out SHARED_LIBRARIES,$(LOCAL_MODULE_CLASS)),)
$(error The integration layer for the nvmake build system supports only shared libraries)
endif

include $(NVIDIA_BASE)
# TODO Enable coverage build

# Set to 1 to do nvmake builds in the unix-build chroot
NV_USE_UNIX_BUILD ?= 0

NVIDIA_NVMAKE_BUILD_TYPE := $(TARGET_BUILD_TYPE)
ifdef DEBUG_MODULE_$(strip $(LOCAL_MODULE))
  NVIDIA_NVMAKE_BUILD_TYPE := debug
endif

NVIDIA_NVMAKE_MODULE_NAME := $(LOCAL_MODULE)

ifeq ($(LOCAL_NVIDIA_NVMAKE_TREE),drv)
  NVIDIA_NVMAKE_TOP := $(NV_GPUDRV_SOURCE)
else
  NVIDIA_NVMAKE_TOP := $(TEGRA_TOP)/gpu/$(LOCAL_NVIDIA_NVMAKE_TREE)
endif

NVIDIA_NVMAKE_UNIX_BUILD_COMMAND := \
  unix-build \
  --no-devrel \
  --extra $(ANDROID_BUILD_TOP) \
  --extra $(P4ROOT)/sw/tools \
  --tools $(P4ROOT)/sw/tools \
  --source $(NVIDIA_NVMAKE_TOP) \
  --extra-with-bind-point $(P4ROOT)/sw/mobile/tools/linux/android/nvmake/unix-build64/lib /lib \
  --extra-with-bind-point $(P4ROOT)/sw/mobile/tools/linux/android/nvmake/unix-build64/lib32 /lib32 \
  --extra-with-bind-point $(P4ROOT)/sw/mobile/tools/linux/android/nvmake/unix-build64/lib64 /lib64 \
  --extra $(P4ROOT)/sw/mobile/tools/linux/android/nvmake

NVIDIA_NVMAKE_TARGET_ABI := androideabi

NVIDIA_NVMAKE_MODULE_PRIVATE_PATH := $(LOCAL_NVIDIA_NVMAKE_OVERRIDE_MODULE_PRIVATE_PATH)

NVIDIA_NVMAKE_MODULE := \
    $(NVIDIA_NVMAKE_TOP)/$(LOCAL_NVIDIA_NVMAKE_BUILD_DIR)/_out/Android_ARMv7_$(NVIDIA_NVMAKE_TARGET_ABI)_$(NVIDIA_NVMAKE_BUILD_TYPE)/$(NVIDIA_NVMAKE_MODULE_PRIVATE_PATH)/$(NVIDIA_NVMAKE_MODULE_NAME)$(LOCAL_MODULE_SUFFIX)

ifneq ($(strip $(SHOW_COMMANDS)),)
  NVIDIA_NVMAKE_VERBOSE := NV_VERBOSE=1
else
  NVIDIA_NVMAKE_VERBOSE := -s
endif

# extra definitions to pass to nvmake
NVIDIA_NVMAKE_EXTRADEFS :=
ifeq ($(NVUB_UNIFIED_BRANCHING_ENABLED),1)
  NVIDIA_NVMAKE_EXTRADEFS += NVUB_UNIFIED_BRANCHING_ENABLED=$(NVUB_UNIFIED_BRANCHING_ENABLED)
  ifdef NVUB_SUPPORTS_T132
    NVIDIA_NVMAKE_EXTRADEFS += NVUB_SUPPORTS_T132=$(NVUB_SUPPORTS_T132)
  endif
endif

#
# Call into the nvmake build system to build the module
#
# Add NVUB_SUPPORTS_TXXX=1 to temporarily enable a chip
#

$(NVIDIA_NVMAKE_MODULE) $(LOCAL_MODULE)_nvmakeclean: NVIDIA_NVMAKE_COMMON_BUILD_PARAMS := \
    TEGRA_TOP=$(TEGRA_TOP) \
    ANDROID_BUILD_TOP=$(ANDROID_BUILD_TOP) \
    OUT=$(OUT) \
    NV_SOURCE=$(NVIDIA_NVMAKE_TOP) \
    NV_TOOLS=$(P4ROOT)/sw/tools \
    NV_HOST_OS=Linux \
    NV_HOST_ARCH=x86 \
    NV_TARGET_OS=Android \
    NV_TARGET_ARCH=ARMv7 \
    NV_BUILD_TYPE=$(NVIDIA_NVMAKE_BUILD_TYPE) \
    NV_COVERAGE_ENABLED=$(NVIDIA_COVERAGE_ENABLED) \
    TARGET_TOOLS_PREFIX=$(abspath $(TARGET_TOOLS_PREFIX)) \
    TARGET_C_INCLUDES="$(foreach inc,external/stlport/stlport $(TARGET_C_INCLUDES) bionic system/core/libsync/include,$(abspath $(inc)))" \
    TARGET_OUT_INTERMEDIATE_LIBRARIES=$(abspath $(TARGET_OUT_INTERMEDIATE_LIBRARIES)) \
    TARGET_LIBGCC=$(TARGET_LIBGCC) \
    $(NVUB_SUPPORTS_FLAG_LIST) \
    $(NVIDIA_NVMAKE_VERBOSE) \
    $(LOCAL_NVIDIA_NVMAKE_ARGS)

ifeq ($(NV_USE_UNIX_BUILD),1)
  $(NVIDIA_NVMAKE_MODULE) $(LOCAL_MODULE)_nvmakeclean: NVIDIA_NVMAKE_COMMAND := \
    $(NVIDIA_NVMAKE_UNIX_BUILD_COMMAND) \
    --newdir $(NVIDIA_NVMAKE_TOP)/$(LOCAL_NVIDIA_NVMAKE_BUILD_DIR) \
    nvmake
else
  $(NVIDIA_NVMAKE_MODULE) $(LOCAL_MODULE)_nvmakeclean: NVIDIA_NVMAKE_COMMAND := \
    $(MAKE) \
    MAKE=$(shell which $(MAKE)) \
    LD_LIBRARY_PATH=$(LD_LIBRARY_PATH) \
    NV_UNIX_BUILD_CHROOT=$(P4ROOT)/sw/tools/unix/hosts/Linux-x86/unix-build \
    -C $(NVIDIA_NVMAKE_TOP)/$(LOCAL_NVIDIA_NVMAKE_BUILD_DIR) \
    -f makefile.nvmk
endif

# We always link nvmake components against these few libraries.
# LOCAL_SHARED_LIBRARIES will enforce the install requirement, but
# LOCAL_ADDITIONAL_DEPENDENCIES will enforce that they are built before nvmake runs
LOCAL_SHARED_LIBRARIES += libc libdl libm libstdc++ libz
# Ensure libgcov_null.so is built if needed.
ifeq ($(NVIDIA_NVMAKE_BUILD_TYPE),debug)
  ifneq ($(NVIDIA_COVERAGE_ENABLED),)
    ifneq ($(LOCAL_NVIDIA_NO_COVERAGE),true)
      ifeq ($(LOCAL_NVIDIA_NULL_COVERAGE),true)
        LOCAL_SHARED_LIBRARIES += libgcov_null
      endif
    endif
  endif
endif

LOCAL_ADDITIONAL_DEPENDENCIES += \
	$(foreach l,$(LOCAL_SHARED_LIBRARIES),$(TARGET_OUT_INTERMEDIATE_LIBRARIES)/$(l).so)

# This target needs to be forced, nvmake will do its own dependency checking
$(NVIDIA_NVMAKE_MODULE): $(call local-intermediates-dir)/import_includes $(LOCAL_ADDITIONAL_DEPENDENCIES) FORCE
	@echo "Build with nvmake: $(PRIVATE_MODULE) ($@)"
	+$(hide) $(NVIDIA_NVMAKE_COMMAND) $(NVIDIA_NVMAKE_COMMON_BUILD_PARAMS) ANDROID_IMPORT_INCLUDES="$(subst -I ,-I$(abspath $(TOP))/,$(shell cat $(PRIVATE_IMPORT_INCLUDES)))" MAKEFLAGS="$(MAKEFLAGS)"

$(LOCAL_MODULE)_nvmakeclean:
	@echo "Clean nvmake build files: $(PRIVATE_MODULE)"
	+$(hide) $(NVIDIA_NVMAKE_COMMAND) $(NVIDIA_NVMAKE_COMMON_BUILD_PARAMS) MAKEFLAGS="$(MAKEFLAGS)" clobber

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
NVIDIA_NVMAKE_TARGET_ABI :=
NVIDIA_NVMAKE_MODULE_PRIVATE_PATH :=
NVIDIA_NVMAKE_UNIX_BUILD_COMMAND :=
