LOCAL_MODULE_CLASS := JAVA_LIBRARIES

include $(NVIDIA_BASE)
include $(BUILD_STATIC_JAVA_LIBRARY)

# BUILD_JAVA_LIBRARY doesn't consider additional dependencies
$(LOCAL_BUILT_MODULE): $(LOCAL_ADDITIONAL_DEPENDENCIES)

# Somewhere dependency is broken for static java libraries in JB-MR2.
# The recipe for ALL_MODULES.$(LOCAL_MODULE).BUILT target is not being
# run and thus static java lib is not found at the location where it should
# be. Making default target droidcore depend on $(LOCAL_BUILT_MODULE) so that
# it gets copied in the location pointed by ALL_MODULES.$(LOCAL_MODULE).BUILT
droidcore: $(LOCAL_BUILT_MODULE)
