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

.PHONY: update-build-properties
# Make default target depend on specific targets required for tegratab
ifeq ($(TARGET_DEVICE),tegratab)
droidcore: update-build-properties factory_bundle
endif

#
# Override fingerprint for tegratab
#
# We are changing TARGET_PRODUCT values to NV_PRODUCT_NAME
# and TARGET_DEVICE value to NV_PRODUCT_DEVICE just for build.prop usage

# original build_desc is reset just after use, re-constructing it here to use
NV_BUILD_DESC_ORIG := $(TARGET_PRODUCT)-$(TARGET_BUILD_VARIANT) $(PLATFORM_VERSION) $(BUILD_ID) $(BUILD_NUMBER) $(BUILD_VERSION_TAGS)

# The string used to uniquely identify this build;  used by the OTA server.
ifneq ($(NV_PRODUCT_NAME),)
ifneq ($(NV_PRODUCT_DEVICE),)
NV_BUILD_FINGERPRINT := $(PRODUCT_BRAND)/$(NV_PRODUCT_NAME)/$(NV_PRODUCT_DEVICE):$(PLATFORM_VERSION)/$(BUILD_ID)/$(BUILD_NUMBER):$(TARGET_BUILD_VARIANT)/$(BUILD_VERSION_TAGS)
else # NV_PRODUCT_DEVICE is not defined
NV_BUILD_FINGERPRINT := $(PRODUCT_BRAND)/$(NV_PRODUCT_NAME)/$(TARGET_DEVICE):$(PLATFORM_VERSION)/$(BUILD_ID)/$(BUILD_NUMBER):$(TARGET_BUILD_VARIANT)/$(BUILD_VERSION_TAGS)
endif

ifneq ($(words $(NV_BUILD_FINGERPRINT)),1)
$(error NV_BUILD_FINGERPRINT cannot contain spaces: "$(NV_BUILD_FINGERPRINT)")
endif

# Change build description which uses TARGET_PRODUCT
NV_BUILD_DESC := $(NV_PRODUCT_NAME)-$(TARGET_BUILD_VARIANT) $(PLATFORM_VERSION) $(BUILD_ID) $(BUILD_NUMBER) $(BUILD_VERSION_TAGS)

else # NV_PRODUCT_NAME is not defined
NV_BUILD_FINGERPRINT := $(BUILD_FINGERPRINT)
NV_BUILD_DESC := $(NV_BUILD_DESC_ORIG)
endif

# Display parameters shown under Settings -> About Phone
ifeq ($(TARGET_BUILD_VARIANT),user)
NV_BUILD_DISPLAY_ID := $(BUILD_DISPLAY_ID)
else
# Non-user builds should show detailed build information
NV_BUILD_DISPLAY_ID := $(NV_BUILD_DESC)
endif

# The mangle tool which changes the value of properties in build.prop
NV_PROP_MANGLE_TOOL := vendor/nvidia/build/tasks/post_process_props.py

update-build-properties: $(INSTALLED_BUILD_PROP_TARGET) $(NV_PROP_MANGLE_TOOL)
	@echo $@ - Changing ro.product.name for $(TARGET_DEVICE)
	@echo OLD ro.product.name - $(TARGET_PRODUCT)
	@echo NEW ro.product.name - $(NV_PRODUCT_NAME)
	$(hide) $(filter %.py,$^) \
		-p ro.product.name \
		-v "$(NV_PRODUCT_NAME)" \
		$(filter %.prop,$^)
	@echo $@ - Changing ro.product.device for $(TARGET_DEVICE)
	@echo OLD ro.product.device - $(TARGET_DEVICE)
	@echo NEW ro.product.device - $(NV_PRODUCT_DEVICE)
	$(hide) $(filter %.py,$^) \
		-p ro.product.device \
		-v "$(NV_PRODUCT_DEVICE)" \
		$(filter %.prop,$^)
	@echo $@ - Changing ro.build.product for $(TARGET_DEVICE)
	@echo OLD ro.build.product - $(TARGET_DEVICE)
	@echo NEW ro.build.product - $(NV_PRODUCT_DEVICE)
	$(hide) $(filter %.py,$^) \
		-p ro.build.product \
		-v "$(NV_PRODUCT_DEVICE)" \
		$(filter %.prop,$^)
	@echo $@ - Changing ro.build.fingerprint for $(TARGET_DEVICE)
	@echo OLD ro.build.fingerprint - $(BUILD_FINGERPRINT)
	@echo NEW ro.build.fingerprint - $(NV_BUILD_FINGERPRINT)
	$(hide) $(filter %.py,$^) \
		-p ro.build.fingerprint \
		-v "$(NV_BUILD_FINGERPRINT)" \
		$(filter %.prop,$^)
	@echo $@ - Changing ro.build.description for $(TARGET_DEVICE)
	@echo OLD ro.build.description - $(NV_BUILD_DESC_ORIG)
	@echo NEW ro.build.description - $(NV_BUILD_DESC)
	$(hide) $(filter %.py,$^) \
		-p ro.build.description \
		-v "$(NV_BUILD_DESC)" \
		$(filter %.prop,$^)
ifneq ($(BUILD_DISPLAY_ID),$(NV_BUILD_DISPLAY_ID))
	@echo $@ - Changing ro.build.display.id for $(TARGET_DEVICE)
	@echo OLD ro.build.display.id - $(BUILD_DISPLAY_ID)
	@echo NEW ro.build.display.id - $(NV_BUILD_DISPLAY_ID)
	$(hide) $(filter %.py,$^) \
		-p ro.build.display.id \
		-v "$(NV_BUILD_DISPLAY_ID)" \
		$(filter %.prop,$^)
endif

# Override factory bundle target so that we can copy an APK inside it
# PRODUCT_FACTORY_BUNDLE_MODULES could not be used for target binaries
# Also PRODUCT_COPY_FILES could not be used for prebuilt apk
ifeq ($(TARGET_DEVICE),tegratab)
factory_bundle_dir := $(PRODUCT_OUT)/factory_bundle
$(eval $(call copy-one-file,$(TARGET_OUT_DATA_APPS)/tmc.apk,$(factory_bundle_dir)/tmc.apk))
nv_factory_copied_files := $(factory_bundle_dir)/tmc.apk
$(eval $(call copy-one-file,$(PRODUCT_OUT)/testcases.xml,$(factory_bundle_dir)/testcases.xml))
nv_factory_copied_files += $(factory_bundle_dir)/testcases.xml

$(INSTALLED_FACTORY_BUNDLE_TARGET): $(nv_factory_copied_files)
endif
