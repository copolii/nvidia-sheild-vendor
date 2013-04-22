# HACKY: PDK fixups
ifeq ($(TARGET_BUILD_PDK),true)
$(call intermediates-dir-for,SHARED_LIBRARIES,libOpenSLES)/export_includes:
	$(hide) mkdir -p $(dir $@) && rm -f $@
	$(hide) touch $@

$(TARGET_OUT_INTERMEDIATE_LIBRARIES)/libOpenSLES.so: $(PDK_FUSION_PLATFORM_ZIP)
	$(hide) unzip -p $(PDK_FUSION_PLATFORM_ZIP) system/lib/libOpenSLES.so >$@
endif
