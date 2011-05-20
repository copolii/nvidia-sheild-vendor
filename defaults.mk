
# Grab name of the makefile to depend on it
ifneq ($(PREV_LOCAL_PATH),$(LOCAL_PATH))
NVIDIA_MAKEFILE := $(lastword $(filter-out $(lastword $(MAKEFILE_LIST)),$(MAKEFILE_LIST)))
PREV_LOCAL_PATH := $(LOCAL_PATH)
endif
include $(CLEAR_VARS)

# Build variables common to all nvidia modules

LOCAL_C_INCLUDES += $(TEGRA_TOP)/core/include
LOCAL_C_INCLUDES += $(TEGRA_TOP)/core/drivers/hwinc

ifneq (,$(findstring core-private,$(LOCAL_PATH)))
LOCAL_C_INCLUDES += $(TEGRA_TOP)/core-private/include
LOCAL_C_INCLUDES += $(TEGRA_TOP)/core-private/drivers/hwinc
endif

ifneq (,$(findstring tests,$(LOCAL_PATH)))
LOCAL_C_INCLUDES += $(TEGRA_TOP)/core-private/include
endif

ifeq ($(TARGET_BUILD_TYPE),debug)
LOCAL_CFLAGS += -DNV_DEBUG=1
# TODO: fix source that relies on these
LOCAL_CFLAGS += -DDEBUG
LOCAL_CFLAGS += -D_DEBUG
# disable all optimizations and enable gdb debugging extensions
LOCAL_CFLAGS += -O0 -ggdb
else
LOCAL_CFLAGS += -DNV_DEBUG=0
endif
LOCAL_CFLAGS += -DNV_IS_AVP=0
LOCAL_CFLAGS += -DNV_BUILD_STUBS=1

LOCAL_PRELINK_MODULE := false

LOCAL_MODULE_TAGS := optional

# clear nvidia local variables to defaults
NVIDIA_CLEARED := true
LOCAL_IDL_INCLUDES := $(TEGRA_TOP)/core/include
LOCAL_IDLFLAGS :=
LOCAL_INTERMEDIATES_DIR :=
LOCAL_NVIDIA_STUBS :=
LOCAL_NVIDIA_DISPATCHERS :=
LOCAL_NVIDIA_SHADERS :=
LOCAL_NVIDIA_GEN_SHADERS :=
LOCAL_NVIDIA_PKG :=
LOCAL_NVIDIA_PKG_DISPATCHER :=
LOCAL_NVIDIA_EXPORTS :=
LOCAL_NVIDIA_NO_COVERAGE :=
LOCAL_NVIDIA_NULL_COVERAGE :=
