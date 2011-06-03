# Enables warnings and warnings as errors for nvidia modules, these warnings are enabled for Linux/LDK builds and should always be enabled for Android as well.
# By default all warnings are turned on and all warnings are treated as errors, there are four variables to control the behaviour from NVIDIA module's Android.mk file.
# LOCAL_NVIDIA_NO_EXTRA_WARNINGS := 1 turns off following warnings
# LOCAL_NVIDIA_NO_WARNINGS_AS_ERRORS :=1 turns off warnings as errors
# LOCAL_NVIDIA_RM_WARNING_FLAGS := <flag> eg: LOCAL_NVIDIA_RM_WARNING_FLAGS := -Wundef, filters out that particular flag.
# LOCAL_NVIDIA_NO_EXTRA_WARNINGS_AS_ERRORS := 1 turns of only extra warnings as errors with help of -Wno-error=<flag>.
# In some cases like in case of -Wundef, -Wno-error=undef does not work so above can be used to filter it out for some modules
# IMPORTANT: All the four variables must be removed from all Android.mk files, and then removed from here so that warnings in NVIDIA modules will never again break our Android builds.

# Returns list of files have extension .cpp in local sources
local-nvidia-module-has-cpp-sources = $(strip $(filter %.cpp,$(LOCAL_SRC_FILES)))

# Because of errors like this we are commenting -Wnested-externs and -Wredundant-decls
# bionic/libc/include/unistd.h: In function 'getpagesize':
# bionic/libc/include/unistd.h:171: error: nested extern declaration of '__page_size'
# bionic/libc/include/unistd.h: In function '__getpageshift':
# bionic/libc/include/unistd.h:175: error: nested extern declaration of '__page_shift'
# bionic/libc/include/strings.h:50: error: redundant redeclaration of 'index'
# bionic/libc/include/strings.h:51: error: redundant redeclaration of 'rindex'
# bionic/libc/include/strings.h:52: error: redundant redeclaration of 'strcasecmp'
# bionic/libc/include/strings.h:53: error: redundant redeclaration of 'strncasecmp'

ifneq ($(LOCAL_NVIDIA_NO_EXTRA_WARNINGS),1)
LOCAL_CFLAGS += -Wmissing-declarations
#LOCAL_CFLAGS += -Wredundant-decls
LOCAL_CFLAGS += -Wcast-align
LOCAL_CFLAGS += -Wundef

# Following warnings are only valid for C, not for C++
ifeq (,$(call local-nvidia-module-has-cpp-sources))
LOCAL_CFLAGS += -Wmissing-prototypes
LOCAL_CFLAGS += -Wstrict-prototypes
#LOCAL_CFLAGS += -Wnested-externs
endif

# Currently there is a bug in sys/cdefs.h, this will satisfy the compiler
# http://code.google.com/p/android/issues/detail?id=14627
LOCAL_CFLAGS += -D__STDC_VERSION__=0
endif

# To turn on warnings as errors
ifneq ($(LOCAL_NVIDIA_NO_WARNINGS_AS_ERRORS),1)
# Add -Werror only if it is not already present in the LOCAL_CFLAGS
ifeq (,$(findstring -Werror, $(LOCAL_CFLAGS)))
LOCAL_CFLAGS += -Werror
endif
endif

# Filter out flags defined in LOCAL_NVIDIA_RM_WARNING_FLAGS from LOCAL_CFLAGS, only used for -Wundef, as it can not be turned off with -Wno-error=undef
ifneq (,$(LOCAL_NVIDIA_RM_WARNING_FLAGS))
LOCAL_CFLAGS := $(filter-out $(LOCAL_NVIDIA_RM_WARNING_FLAGS),$(LOCAL_CFLAGS))
endif

