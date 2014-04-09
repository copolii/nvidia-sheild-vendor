# Temporary WAR, since executables now default to only trying the first architecture
ifeq ($(LOCAL_MODULE_TARGET_ARCH),arm)
ifeq ($(LOCAL_MULTILIB),)
LOCAL_MULTILIB := 32
endif
endif

LOCAL_MODULE_CLASS := EXECUTABLES

include $(NVIDIA_BASE)
include $(NVIDIA_WARNINGS)
include $(NVIDIA_COVERAGE)
include $(BUILD_EXECUTABLE)
