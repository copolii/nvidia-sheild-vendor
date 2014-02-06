NVIDIA_NVMAKE_ADDITIONAL_DEPENDENCIES := \
	$(LOCAL_ADDITIONAL_DEPENDENCIES) \
	$(foreach l,$(LOCAL_SHARED_LIBRARIES),$(TARGET_OUT_INTERMEDIATE_LIBRARIES)/$(l).so)

NVIDIA_NVMAKE_TARGET_ABI := androideabi

NVIDIA_NVMAKE_MODULE := \
    $(NVIDIA_NVMAKE_TOP)/$(LOCAL_NVIDIA_NVMAKE_BUILD_DIR)/_out/Android_ARMv7_$(NVIDIA_NVMAKE_TARGET_ABI)_$(NVIDIA_NVMAKE_BUILD_TYPE)/$(NVIDIA_NVMAKE_MODULE_PRIVATE_PATH)/$(NVIDIA_NVMAKE_MODULE_NAME)$(LOCAL_MODULE_SUFFIX)


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
    LD_LIBRARY_PATH=$(NVIDIA_NVMAKE_LIBRARY_PATH) \
    NV_UNIX_BUILD_CHROOT=$(P4ROOT)/sw/tools/unix/hosts/Linux-x86/unix-build \
    -C $(NVIDIA_NVMAKE_TOP)/$(LOCAL_NVIDIA_NVMAKE_BUILD_DIR) \
    -f makefile.nvmk
endif

# This target needs to be forced, nvmake will do its own dependency checking
$(NVIDIA_NVMAKE_MODULE): $(call local-intermediates-dir)/import_includes $(NVIDIA_NVMAKE_ADDITIONAL_DEPENDENCIES) FORCE
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

NVIDIA_NVMAKE_MODULE :=
NVIDIA_NVMAKE_TARGET_ABI :=
NVIDIA_NVMAKE_ADDITIONAL_DEPENDENCIES :=
