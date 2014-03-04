ifeq ($(LOCAL_MODULE_CLASS),SHARED_LIBRARIES)
OVERRIDE_BUILT_MODULE_PATH := $($(LOCAL_2ND_ARCH_VAR_PREFIX)TARGET_OUT_INTERMEDIATE_LIBRARIES)
endif

NVIDIA_NVMAKE_ADDITIONAL_DEPENDENCIES := \
	$(LOCAL_ADDITIONAL_DEPENDENCIES) \
	$(foreach l,$(LOCAL_SHARED_LIBRARIES),$($(LOCAL_2ND_ARCH_VAR_PREFIX)TARGET_OUT_INTERMEDIATE_LIBRARIES)/$(l).so) \
	$(foreach l,$(LOCAL_STATIC_LIBRARIES),$(call intermediates-dir-for, \
	  STATIC_LIBRARIES,$(l),,,$(LOCAL_2ND_ARCH_VAR_PREFIX))/$(l).a)

ifeq ($(TARGET_$(LOCAL_2ND_ARCH_VAR_PREFIX)ARCH),arm)
NVIDIA_NVMAKE_TARGET_ABI := _androideabi
NVIDIA_NVMAKE_TARGET_ARCH := ARMv7
else
NVIDIA_NVMAKE_TARGET_ABI :=
NVIDIA_NVMAKE_TARGET_ARCH := AArch64
endif

NVIDIA_NVMAKE_MODULE := \
    $(NVIDIA_NVMAKE_TOP)/$(LOCAL_NVIDIA_NVMAKE_BUILD_DIR)/_out/Android_$(NVIDIA_NVMAKE_TARGET_ARCH)$(NVIDIA_NVMAKE_TARGET_ABI)_$(NVIDIA_NVMAKE_BUILD_TYPE)/$(NVIDIA_NVMAKE_MODULE_PRIVATE_PATH)/$(NVIDIA_NVMAKE_MODULE_NAME)$(LOCAL_MODULE_SUFFIX)


# Android builds set NV_INTERNAL_PROFILE in internal builds, and nothing
# on external builds. Convert this to nvmake convention.
ifeq ($(NV_INTERNAL_PROFILE),1)
NVIDIA_NVMAKE_PROFILE :
else
NVIDIA_NVMAKE_PROFILE := NV_EXTERNAL_PROFILE=1
endif

#
# Bring module from the nvmake build output, and apply the usual
# processing for shared library or executable.
#

include $(BUILD_SYSTEM)/dynamic_binary.mk

$(linked_module): $(NVIDIA_NVMAKE_MODULE) | $(ACP)
	@echo "Copy from nvmake output: $(PRIVATE_MODULE) ($@)"
	$(copy-file-to-target)

#
# Call into the nvmake build system to build the module
#
# Add NVUB_SUPPORTS_TXXX=1 to temporarily enable a chip
#

$(NVIDIA_NVMAKE_MODULE) $(my_register_name)_nvmakeclean: NVIDIA_NVMAKE_COMMON_BUILD_PARAMS := \
    TEGRA_TOP=$(TEGRA_TOP) \
    ANDROID_BUILD_TOP=$(ANDROID_BUILD_TOP) \
    OUT=$(OUT) \
    NV_SOURCE=$(NVIDIA_NVMAKE_TOP) \
    NV_TOOLS=$(P4ROOT)/sw/tools \
    NV_HOST_OS=Linux \
    NV_HOST_ARCH=x86 \
    NV_TARGET_OS=Android \
    NV_TARGET_ARCH=$(NVIDIA_NVMAKE_TARGET_ARCH) \
    NV_BUILD_TYPE=$(NVIDIA_NVMAKE_BUILD_TYPE) \
    $(NVIDIA_NVMAKE_PROFILE) \
    NV_COVERAGE_ENABLED=$(NVIDIA_COVERAGE_ENABLED) \
    TARGET_TOOLS_PREFIX=$(abspath $($(LOCAL_2ND_ARCH_VAR_PREFIX)TARGET_TOOLS_PREFIX)) \
    TARGET_C_INCLUDES="$(foreach inc,external/stlport/stlport $($(LOCAL_2ND_ARCH_VAR_PREFIX)TARGET_C_INCLUDES) bionic system/core/libsync/include,$(abspath $(inc)))" \
    TARGET_OUT_INTERMEDIATE_LIBRARIES=$(abspath $($(LOCAL_2ND_ARCH_VAR_PREFIX)TARGET_OUT_INTERMEDIATE_LIBRARIES)) \
    TARGET_LIBGCC=$($(LOCAL_2ND_ARCH_VAR_PREFIX)TARGET_LIBGCC) \
    TARGET_GLOBAL_CFLAGS="$($(LOCAL_2ND_ARCH_VAR_PREFIX)TARGET_GLOBAL_CFLAGS)" \
    TARGET_GLOBAL_LDFLAGS="$($(LOCAL_2ND_ARCH_VAR_PREFIX)TARGET_GLOBAL_LDFLAGS)" \
    $(NVUB_SUPPORTS_FLAG_LIST) \
    $(NVIDIA_NVMAKE_VERBOSE) \
    $(LOCAL_NVIDIA_NVMAKE_ARGS)

ifeq ($(NV_USE_UNIX_BUILD),1)
  $(NVIDIA_NVMAKE_MODULE) $(my_register_name)_nvmakeclean: NVIDIA_NVMAKE_COMMAND := \
    $(NVIDIA_NVMAKE_UNIX_BUILD_COMMAND) \
    --newdir $(NVIDIA_NVMAKE_TOP)/$(LOCAL_NVIDIA_NVMAKE_BUILD_DIR) \
    nvmake
else
  $(NVIDIA_NVMAKE_MODULE) $(my_register_name)_nvmakeclean: NVIDIA_NVMAKE_COMMAND := \
    $(MAKE) \
    MAKE=$(shell which $(MAKE)) \
    LD_LIBRARY_PATH=$(NVIDIA_NVMAKE_LIBRARY_PATH) \
    NV_UNIX_BUILD_CHROOT=$(P4ROOT)/sw/tools/unix/hosts/Linux-x86/unix-build \
    -C $(NVIDIA_NVMAKE_TOP)/$(LOCAL_NVIDIA_NVMAKE_BUILD_DIR) \
    -f makefile.nvmk
endif

# This target needs to be forced, nvmake will do its own dependency checking
$(NVIDIA_NVMAKE_MODULE): $(intermediates)/import_includes $(NVIDIA_NVMAKE_ADDITIONAL_DEPENDENCIES) FORCE
	@echo "Build with nvmake: $(PRIVATE_MODULE) ($@)"
	+$(hide) $(NVIDIA_NVMAKE_COMMAND) $(NVIDIA_NVMAKE_COMMON_BUILD_PARAMS) ANDROID_IMPORT_INCLUDES="$(subst -I ,-I$(abspath $(TOP))/,$(shell cat $(PRIVATE_IMPORT_INCLUDES)))" MAKEFLAGS="$(MAKEFLAGS)"

$(my_register_name)_nvmakeclean:
	@echo "Clean nvmake build files: $(PRIVATE_MODULE)"
	+$(hide) $(NVIDIA_NVMAKE_COMMAND) $(NVIDIA_NVMAKE_COMMON_BUILD_PARAMS) MAKEFLAGS="$(MAKEFLAGS)" clobber

.PHONY: $(my_register_name)_nvmakeclean

#
# Make the module's clean target descend into nvmake.
#

$(cleantarget):: $(my_register_name)_nvmakeclean

NVIDIA_NVMAKE_MODULE :=
NVIDIA_NVMAKE_TARGET_ABI :=
NVIDIA_NVMAKE_TARGET_ARCH :=
NVIDIA_NVMAKE_ADDITIONAL_DEPENDENCIES :=
NVIDIA_NVMAKE_PROFILE :=
