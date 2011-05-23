#
# Linux kernel and loadable kernel modules
#
ifneq ($(TARGET_NO_KERNEL),true)

KERNEL_PATH ?= kernel

#kernel_version := $(strip $(shell head $(KERNEL_PATH)/Makefile | \
#	grep "SUBLEVEL =" | cut -d= -f2))

# Tegra platforms that have their own defconfig file
TEGRA_PLATFORM_DEFCONFIGS := aruba2 cardhu curacao enterprise whistler bonaire

TARGET_KERNEL_CONFIG ?= tegra_defconfig
ifeq (,$(filter-out $(TEGRA_PLATFORM_DEFCONFIGS),$(TARGET_PRODUCT)))
    TARGET_KERNEL_CONFIG := tegra_$(TARGET_PRODUCT)_android_defconfig
endif

_kernel_intermediates := $(TARGET_OUT_INTERMEDIATES)/KERNEL
dotconfig := $(_kernel_intermediates)/.config

# We should rather use CROSS_COMPILE=$(PRIVATE_TOPDIR)/$(TARGET_TOOLS_PREFIX).
define kernel-make
$(MAKE) -C $(PRIVATE_SRC_PATH) \
    ARCH=$(TARGET_ARCH) \
    CROSS_COMPILE=$(PRIVATE_TOPDIR)/prebuilt/linux-x86/toolchain/arm-eabi-4.4.3/bin/arm-eabi- \
    O=$(PRIVATE_TOPDIR)/$(PRIVATE_KBUILD_OUT) \
    $(if $(SHOW_COMMANDS),V=1)
endef

BUILT_KERNEL_TARGET := $(_kernel_intermediates)/arch/$(TARGET_ARCH)/boot/zImage

$(dotconfig): $(KERNEL_PATH)/arch/$(TARGET_ARCH)/configs/$(TARGET_KERNEL_CONFIG)
	@echo "Kernel config"
	@mkdir -p $(PRIVATE_KBUILD_OUT)
	$(hide) $(kernel-make) $(TARGET_KERNEL_CONFIG)

# TODO: figure out a way of not forcing kernel & module builds.
# + in front of kernel-make will enable job control (parallelization).
$(BUILT_KERNEL_TARGET): $(dotconfig) FORCE
	@echo "Kernel build"
	@mkdir -p $(PRIVATE_KBUILD_OUT)
	+$(hide) $(kernel-make) zImage

# This will add all kernel modules we build for inclusion the system
# image - no blessing takes place.
# FIXME: there may be no modules built.
kmodules: $(BUILT_KERNEL_TARGET) FORCE
	@echo "Kernel modules build"
	+$(hide) $(kernel-make) modules
	mkdir -p $(TARGET_OUT)/lib/modules
	cp -v `find $(PRIVATE_TOPDIR)/$(PRIVATE_KBUILD_OUT) -name "*.ko"` $(TARGET_OUT)/lib/modules

# At this stage, BUILT_SYSTEMIMAGE in build/core/Makefile has not yet
# been defined, so we cannot rely on it.
_systemimage_intermediates_kmodules := \
    $(call intermediates-dir-for,PACKAGING,systemimage)
BUILT_SYSTEMIMAGE_KMODULES := $(_systemimage_intermediates_kmodules)/system.img

# Unless we hardcode the list of kernel modules, we cannot create
# a proper dependency from systemimage to the kernel modules.
# If we decide to hardcode later on, BUILD_PREBUILT (or maybe
# PRODUCT_COPY_FILES) can be used for including the modules in the image.
# For now, let's rely on an explicit dependency.
$(BUILT_SYSTEMIMAGE_KMODULES): kmodules

$(INSTALLED_KERNEL_TARGET): $(BUILT_KERNEL_TARGET) | $(ACP)
	$(copy-file-to-target)

kernel: $(INSTALLED_KERNEL_TARGET) kmodules

kernel-%:
	@mkdir -p $(PRIVATE_KBUILD_OUT)
	$(hide) $(kernel-make) $*

.PHONY: kernel kernel-% kmodules

# Set private variables for all builds. TODO: Why?
kernel kernel-% kmodules $(dotconfig) $(BUILT_KERNEL_TARGET): PRIVATE_SRC_PATH := $(KERNEL_PATH)
kernel kernel-% kmodules $(dotconfig) $(BUILT_KERNEL_TARGET): PRIVATE_KBUILD_OUT := $(TARGET_OUT_INTERMEDIATES)/KERNEL
kernel kernel-% kmodules $(dotconfig) $(BUILT_KERNEL_TARGET): PRIVATE_TOPDIR := $(shell pwd)

endif
# of ifneq ($(TARGET_NO_KERNEL),true)

# FIXME: This should be moved to a file of its own.
# TODO: This may not be what we want.
.PHONY: dev
dev: droidcore
