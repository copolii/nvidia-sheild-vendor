################################### tell Emacs this is a -*- makefile-gmake -*-
#
# Copyright (c) 2014, NVIDIA CORPORATION.  All rights reserved.
#
# NVIDIA CORPORATION and its licensors retain all intellectual property
# and proprietary rights in and to this software, related documentation
# and any modifications thereto.  Any use, reproduction, disclosure or
# distribution of this software and related documentation without an express
# license agreement from NVIDIA CORPORATION is strictly prohibited.
#
###############################################################################
#
# This makefile fragment is used to execute a tmake part umbrella and
# add the resulting build artifacts as prebuilts in the Android build
#
###############################################################################
#
# Sanity checks for mandatory configuration variables
#
# LOCAL_NVIDIA_TMAKE_PART_NAME - name of the tmake part umbrella
#
LOCAL_NVIDIA_TMAKE_PART_NAME := $(strip $(LOCAL_NVIDIA_TMAKE_PART_NAME))
ifeq ($(LOCAL_NVIDIA_TMAKE_PART_NAME),)
  $(error $(LOCAL_PATH): LOCAL_NVIDIA_TMAKE_PART_NAME is not defined)
endif
#
# LOCAL_NVIDIA_TMAKE_PART_ARTIFACT - path to build artifact for LOCAL_MODULE
#
LOCAL_NVIDIA_TMAKE_PART_ARTIFACT := $(strip $(LOCAL_NVIDIA_TMAKE_PART_ARTIFACT))
ifeq ($(LOCAL_NVIDIA_TMAKE_PART_ARTIFACT),)
  $(error $(LOCAL_PATH): LOCAL_NVIDIA_TMAKE_PART_ARTIFACT is not defined)
endif
#
# Map REFERENCE_DEVICE to a reference board supported by tmake
#
#   <REFERENCE_DEVICE value>=<tmake board name>
#
_tmake_config_devices := \
	ardbeg=ardbeg \
	loki=loki \
	t132=t132ref
_tmake_config_device  := $(word 2,$(subst =, ,$(filter $(REFERENCE_DEVICE)=%, $(_tmake_config_devices))))
ifndef _tmake_config_device
  $(error $(LOCAL_PATH): reference device "$(REFERENCE_DEVICE)" is not supported)
endif


###############################################################################
#
# Translate from Android to tmake SW Build system
#
ifneq ($(filter tf tlk y,$(SECURE_OS_BUILD)),)
_tmake_config_secureos := 1
else
_tmake_config_secureos := 0
endif
ifneq ($(SHOW_COMMANDS),)
_tmake_config_verbose  := 1
else
_tmake_config_verbose  := 0
endif
ifeq ($(TARGET_BUILD_TYPE),debug)
_tmake_config_debug    := 1
else
_tmake_config_debug    := 0
endif


###############################################################################
#
# tmake part umbrellas build multiple different components in one go. Thus they
# don't fit into the standard Android directory structure under $(OUT_DIR).
#
# This is the root directory to which an umbrella specific part will be added.
#
_tmake_intermediates := $(OUT_DIR)/tmake/part/$(LOCAL_NVIDIA_TMAKE_PART_NAME)


###############################################################################
#
# Umbrella specific configuration
#
ifeq ($(LOCAL_NVIDIA_TMAKE_PART_NAME),bootloader)
# bootloader is OS, security & board specific
_tmake_config_extra  := \
		NV_BUILD_CONFIGURATION_IS_SECURE_OS=$(_tmake_config_secureos) \
		NV_BUILD_SYSTEM_TYPE=android \
		NV_TARGET_BOARD=$(_tmake_config_device)
# Android does not support building secure & non-secure in same work tree
_tmake_intermediates := $(_tmake_intermediates)_$(_tmake_config_device)_$(TARGET_BUILD_TYPE)

else ifeq ($(LOCAL_NVIDIA_TMAKE_PART_NAME),nvtboot)
# nvtboot is security & board specific (= board determines chip family)
_tmake_config_extra  := \
		NV_BUILD_CONFIGURATION_IS_SECURE_OS=$(_tmake_config_secureos) \
		NV_TARGET_BOARD=$(_tmake_config_device)
# Android does not support building secure & non-secure in same work tree
_tmake_intermediates := $(_tmake_intermediates)_$(_tmake_config_device)_$(TARGET_BUILD_TYPE)

else ifeq ($(LOCAL_NVIDIA_TMAKE_PART_NAME),nvflash)
# nvflash is a host tool, agnostic to target configuration
_tmake_config_extra  :=
# NOTE: build type for host bits is also controlled by TARGET_BUILD_TYPE
_tmake_intermediates := $(_tmake_intermediates)_$(HOST_BUILD_TYPE)_$(TARGET_BUILD_TYPE)

#
# @TODO: support for nvgetdtb
#
else
  $(error $(LOCAL_PATH): tmake part umbrella "$(LOCAL_NVIDIA_TMAKE_PART_NAME)" is not supported)
endif


###############################################################################
#
# Dependency between tmake build and Android module
#
_tmake_part_stamp := $(_tmake_intermediates)/tmake.stamp


###############################################################################
#
# Execute tmake part umbrella
#
# This part can only be included once per tmake part umbrella.
#
ifndef _tmake_part_$(LOCAL_NVIDIA_TMAKE_PART_NAME)_was_included
_tmake_part_$(LOCAL_NVIDIA_TMAKE_PART_NAME)_was_included := 1

_tmake_part_umbrella := $(TEGRA_TOP)/tmake/umbrella/parts/Makefile.$(LOCAL_NVIDIA_TMAKE_PART_NAME)

# make sure tmake build is entered every time
.PHONY: $(_tmake_part_stamp)

$(_tmake_part_stamp): PRIVATE_TMAKE_CONFIG_DEBUG   := $(_tmake_config_debug)
$(_tmake_part_stamp): PRIVATE_TMAKE_CONFIG_EXTRA   := $(_tmake_config_extra)
$(_tmake_part_stamp): PRIVATE_TMAKE_CONFIG_VERBOSE := $(_tmake_config_verbose)
$(_tmake_part_stamp): PRIVATE_TMAKE_INTERMEDIATES  := $(if $(filter-out /%,$(_tmake_intermediates)),$(ANDROID_BUILD_TOP)/)$(_tmake_intermediates)
$(_tmake_part_stamp): PRIVATE_TMAKE_PART_NAME      := $(LOCAL_TMAKE_PART_NAME)
$(_tmake_part_stamp): PRIVATE_TMAKE_PART_UMBRELLA  := $(_tmake_part_umbrella)

$(_tmake_intermediates):
	$(hide)mkdir -p $@

$(_tmake_part_stamp): $(_tmake_part_umbrella) | $(_tmake_intermediates)
	@echo Executing tmake "$(PRIVATE_TMAKE_PART_NAME)" part umbrella build
	$(hide)rm -f $@
	$(hide)$(MAKE) -C $(TEGRA_TOP) -f $(PRIVATE_TMAKE_PART_UMBRELLA) \
		NV_BUILD_CONFIGURATION_IS_DEBUG=$(PRIVATE_TMAKE_CONFIG_DEBUG) \
		NV_BUILD_CONFIGURATION_IS_VERBOSE=$(PRIVATE_TMAKE_CONFIG_VERBOSE) \
		$(PRIVATE_TMAKE_CONFIG_EXTRA) \
		NV_OUTDIR=$(PRIVATE_TMAKE_INTERMEDIATES)
	$(hide)touch $@
endif


###############################################################################
#
# The actual Android module: map tmake build artifact to Android prebuilt
#
LOCAL_PREBUILT_MODULE_FILE := $(_tmake_intermediates)/nvidia/$(LOCAL_NVIDIA_TMAKE_PART_ARTIFACT)

$(LOCAL_PREBUILT_MODULE_FILE): $(_tmake_part_stamp)

include $(NVIDIA_PREBUILT)


###############################################################################
#
# variable cleanup
#
_tmake_config_debug    :=
_tmake_config_device   :=
_tmake_config_devices  :=
_tmake_config_extra    :=
_tmake_config_secureos :=
_tmake_config_verbose  :=
_tmake_intermediates   :=
_tmake_part_stamp      :=
_tmake_part_umbrella   :=


# Local Variables:
# indent-tabs-mode: t
# tab-width: 8
# End:
# vi: set tabstop=8 noexpandtab:
