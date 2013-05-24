# HACK: PDK fixups
$(shell mkdir -p $(OUT)/obj/SHARED_LIBRARIES/libOpenSLES_intermediates/export_includes)
$(shell mkdir -p $(OUT)/obj/lib)
$(shell unzip -p $(PDK_FUSION_PLATFORM_ZIP) system/lib/libOpenSLES.so >$(OUT)/obj/lib/libOpenSLES.so)

