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
# Override fingerprint for tegratab
#
.PHONY: update-tegratab-build-fingerprint
droidcore: update-tegratab-build-fingerprint

# We are changing TARGET_PRODUCT values to NV_PRODUCT_NAME just for build.prop usage

ifneq ($(NV_PRODUCT_NAME),)
# The string used to uniquely identify this build;  used by the OTA server.
NV_BUILD_FINGERPRINT := $(PRODUCT_BRAND)/$(NV_PRODUCT_NAME)/$(TARGET_DEVICE):$(PLATFORM_VERSION)/$(BUILD_ID)/$(BUILD_NUMBER):$(TARGET_BUILD_VARIANT)/$(BUILD_VERSION_TAGS)
ifneq ($(words $(NV_BUILD_FINGERPRINT)),1)
  $(error NV_BUILD_FINGERPRINT cannot contain spaces: "$(NV_BUILD_FINGERPRINT)")
endif

# Change build description which uses TARGET_PRODUCT
# original build_desc is reset just after use, re-constructing to show what it was
NV_BUILD_DESC_ORIG := $(TARGET_PRODUCT)-$(TARGET_BUILD_VARIANT) $(PLATFORM_VERSION) $(BUILD_ID) $(BUILD_NUMBER) $(BUILD_VERSION_TAGS)
NV_BUILD_DESC := $(NV_PRODUCT_NAME)-$(TARGET_BUILD_VARIANT) $(PLATFORM_VERSION) $(BUILD_ID) $(BUILD_NUMBER) $(BUILD_VERSION_TAGS)

# Display parameters shown under Settings -> About Phone
ifeq ($(TARGET_BUILD_VARIANT),user)
  NV_BUILD_DISPLAY_ID := $(BUILD_DISPLAY_ID)
else
  # Non-user builds should show detailed build information
  NV_BUILD_DISPLAY_ID := $(NV_BUILD_DESC)
endif
endif

# The mangle tool which changes the value of properties in build.prop
NV_PROP_MANGLE_TOOL := vendor/nvidia/build/tasks/post_process_props.py

update-tegratab-build-fingerprint: $(INSTALLED_BUILD_PROP_TARGET) $(NV_PROP_MANGLE_TOOL)
ifeq ($(TARGET_DEVICE),tegratab)
ifneq ($(NV_PRODUCT_NAME),)
	@echo $@ - Changing ro.product.name for $(TARGET_DEVICE)
	@echo OLD ro.product.name - $(TARGET_PRODUCT)
	@echo NEW ro.product.name - $(NV_PRODUCT_NAME)
	$(hide) $(filter %.py,$^) \
		-p ro.product.name \
		-v "$(NV_PRODUCT_NAME)" \
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
else # NV_PRODUCT_NAME is null
	@echo $@ - Skiping for $(TARGET_DEVICE), Null NV_PRODUCT_NAME=$(NV_PRODUCT_NAME)
endif
else # other boards, no need to do anything
	@echo $@ - Skiping for $(TARGET_DEVICE)
endif

