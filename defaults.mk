
# Grab name of the makefile to depend on it
ifneq ($(PREV_LOCAL_PATH),$(LOCAL_PATH))
NVIDIA_MAKEFILE := $(lastword $(filter-out $(lastword $(MAKEFILE_LIST)),$(MAKEFILE_LIST)))
PREV_LOCAL_PATH := $(LOCAL_PATH)
endif
include $(CLEAR_VARS)

# Build variables common to all nvidia modules

LOCAL_C_INCLUDES += $(TEGRA_ROOT)/include
LOCAL_C_INCLUDES += $(TEGRA_ROOT)/drivers/hwinc

ifneq (,$(findstring core-private,$(LOCAL_PATH)))
LOCAL_C_INCLUDES += $(TEGRA_ROOT)/../core-private/include
LOCAL_C_INCLUDES += $(TEGRA_ROOT)/../core-private/drivers/hwinc
endif

ifeq ($(TARGET_BUILD_TYPE),debug)
LOCAL_CFLAGS += -DNV_DEBUG=1
# TODO: fix source that relies on these
LOCAL_CFLAGS += -DDEBUG
LOCAL_CFLAGS += -D_DEBUG
else
LOCAL_CFLAGS += -DNV_DEBUG=0
endif
LOCAL_CFLAGS += -DNV_IS_AVP=0
LOCAL_CFLAGS += -DNV_BUILD_STUBS=1

LOCAL_PRELINK_MODULE := false

# clear nvidia local variables to defaults
NVIDIA_CLEARED := true
LOCAL_IDL_INCLUDES := $(TEGRA_ROOT)/include
LOCAL_IDLFLAGS :=
LOCAL_NVIDIA_STUBS :=
LOCAL_NVIDIA_DISPATCHERS :=
LOCAL_NVIDIA_SHADERS :=
LOCAL_NVIDIA_GEN_SHADERS :=
LOCAL_NVIDIA_PKG :=
LOCAL_NVIDIA_PKG_DISPATCHER :=
LOCAL_NVIDIA_EXPORTS :=
