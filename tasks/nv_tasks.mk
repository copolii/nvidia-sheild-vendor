#
# This file is included from $TOP/build/core/Makefile
# It has those variables available which are set from above Makefile
#

#
# Override OTA update package target (run with -n)
# Used for developer OTA packages which legitimately need to go back and forth
#
$(INTERNAL_OTA_PACKAGE_TARGET): $(BUILT_TARGET_FILES_PACKAGE) $(DISTTOOLS)
	@echo "Package Dev OTA: $@"
	$(hide) $(TOP)/build/tools/releasetools/ota_from_target_files -n -v \
	   -p $(HOST_OUT) \
	   -k $(KEY_CERT_PAIR) \
	   $(BUILT_TARGET_FILES_PACKAGE) $@

#
# Override properties in build.prop
#
ifneq ($(wildcard vendor/nvidia/$(TARGET_PRODUCT)/sku-properties.xml),)
# SKU manifest containing properties and values to changes
NV_SKU_MANIFEST := vendor/nvidia/$(TARGET_PRODUCT)/sku-properties.xml
# Tool which changes the value of properties in build.prop
NV_PROP_MANGLE_TOOL := vendor/nvidia/build/tasks/process_build_props.py

droidcore: update-build-properties
.PHONY: update-build-properties

update-build-properties: $(INSTALLED_BUILD_PROP_TARGET) \
	                 $(NV_PROP_MANGLE_TOOL) \
			 $(NV_SKU_MANIFEST)
	@echo $@ - Changing properties for $(TARGET_PRODUCT)
	$(hide) $(filter %.py,$^) \
		-s $(NV_TN_SKU) \
		-m $(NV_SKU_MANIFEST) \
		-b $(filter %.prop,$^)
endif

# Override factory bundle target so that we can copy an APK inside it
# PRODUCT_FACTORY_BUNDLE_MODULES could not be used for target binaries
# Also PRODUCT_COPY_FILES could not be used for prebuilt apk
ifeq ($(TARGET_DEVICE),tegratab)
# Let the defaualt target depend on factory_bundle target
droidcore: factory_bundle
factory_bundle_dir := $(PRODUCT_OUT)/factory_bundle
$(eval $(call copy-one-file,$(TARGET_OUT_DATA_APPS)/tmc.apk,$(factory_bundle_dir)/tmc.apk))
nv_factory_copied_files := $(factory_bundle_dir)/tmc.apk
$(eval $(call copy-one-file,$(PRODUCT_OUT)/testcases.xml,$(factory_bundle_dir)/testcases.xml))
nv_factory_copied_files += $(factory_bundle_dir)/testcases.xml

$(INSTALLED_FACTORY_BUNDLE_TARGET): $(nv_factory_copied_files)
endif
