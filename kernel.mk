#
# Linux kernel and loadable kernel modules
#
ifneq ($(TARGET_NO_KERNEL),true)

ifneq ($(TOP),.)
$(error Kernel build assumes TOP == . i.e Android build has been started from TOP/Makefile )
endif

# Android build is started from the $TOP/Makefile, therefore $(CURDIR)
# gives the absolute path to the TOP.
KERNEL_PATH ?= $(CURDIR)/kernel

#kernel_version := $(strip $(shell head $(KERNEL_PATH)/Makefile | \
#	grep "SUBLEVEL =" | cut -d= -f2))

ifeq ($(TARGET_TEGRA_VERSION),ap20)
    TARGET_KERNEL_CONFIG ?= tegra_android_defconfig
else
ifeq ($(TARGET_TEGRA_VERSION),t30)
    TARGET_KERNEL_CONFIG ?= tegra3_android_defconfig
endif
endif

ifeq ($(wildcard $(KERNEL_PATH)/arch/arm/configs/$(TARGET_KERNEL_CONFIG)),)
    $(error Could not find kernel defconfig for board)
endif

# Always use absolute path for NV_KERNEL_INTERMEDIATES_DIR
ifneq ($(filter /%, $(TARGET_OUT_INTERMEDIATES)),)
NV_KERNEL_INTERMEDIATES_DIR := $(TARGET_OUT_INTERMEDIATES)/KERNEL
else
NV_KERNEL_INTERMEDIATES_DIR := $(CURDIR)/$(TARGET_OUT_INTERMEDIATES)/KERNEL
endif

dotconfig := $(NV_KERNEL_INTERMEDIATES_DIR)/.config

# Always use absolute path for NV_KERNEL_MODULES_TARGET_DIR
ifneq ($(filter /%, $(TARGET_OUT)),)
NV_KERNEL_MODULES_TARGET_DIR := $(TARGET_OUT)/lib/modules
else
NV_KERNEL_MODULES_TARGET_DIR := $(CURDIR)/$(TARGET_OUT)/lib/modules
endif

KERNEL_EXTRA_ARGS=
OS=$(shell uname)
ifeq ($(OS),Darwin)
  # check prerequisites
  ifeq ($(GNU_COREUTILS),)
    $(error GNU_COREUTILS is not set)
  endif
  ifeq ($(wildcard $(GNU_COREUTILS)/stat),)
    $(error $(GNU_COREUTILS)/stat not found. Please install GNU coreutils.)
  endif

  # add GNU stat to the path
  KERNEL_EXTRA_ENV=env PATH=$(GNU_COREUTILS):$(PATH)
  # bring in our elf.h
  KERNEL_EXTRA_ARGS=HOST_EXTRACFLAGS=-I$(TOP)/../vendor/nvidia/tegra/core-private/include\ -DKBUILD_NO_NLS
  HOSTTYPE=darwin-x86
endif

ifeq ($(OS),Linux)
  KERNEL_EXTRA_ENV=
  HOSTTYPE=linux-x86
endif

# We should rather use CROSS_COMPILE=$(PRIVATE_TOPDIR)/$(TARGET_TOOLS_PREFIX).
# Absolute paths used in all path variables.
define kernel-make
$(KERNEL_EXTRA_ENV) $(MAKE) -C $(PRIVATE_SRC_PATH) \
    ARCH=$(TARGET_ARCH) \
    CROSS_COMPILE=$(PRIVATE_TOPDIR)/prebuilt/$(HOSTTYPE)/toolchain/arm-eabi-4.4.3/bin/arm-eabi- \
    O=$(NV_KERNEL_INTERMEDIATES_DIR) $(KERNEL_EXTRA_ARGS) \
    $(if $(SHOW_COMMANDS),V=1)
endef

BUILT_KERNEL_TARGET := $(NV_KERNEL_INTERMEDIATES_DIR)/arch/$(TARGET_ARCH)/boot/zImage

$(dotconfig): $(KERNEL_PATH)/arch/$(TARGET_ARCH)/configs/$(TARGET_KERNEL_CONFIG) | $(NV_KERNEL_INTERMEDIATES_DIR)
	@echo "Kernel config"
	$(hide) $(kernel-make) $(TARGET_KERNEL_CONFIG)
ifeq ($(SECURE_OS_BUILD),y)
	@echo "SecureOS enabled kernel"
	$(KERNEL_PATH)/scripts/config --file $(dotconfig) --enable TRUSTED_FOUNDATIONS
endif

# TODO: figure out a way of not forcing kernel & module builds.
# + in front of kernel-make will enable job control (parallelization).
$(BUILT_KERNEL_TARGET): $(dotconfig) FORCE | $(NV_KERNEL_INTERMEDIATES_DIR)
	@echo "Kernel build"
	+$(hide) $(kernel-make) zImage

# This will add all kernel modules we build for inclusion the system
# image - no blessing takes place.
kmodules: $(BUILT_KERNEL_TARGET) FORCE | $(NV_KERNEL_INTERMEDIATES_DIR) $(NV_KERNEL_MODULES_TARGET_DIR)
	@echo "Kernel modules build"
	+$(hide) $(kernel-make) modules
	find $(NV_KERNEL_INTERMEDIATES_DIR) -name "*.ko" -print0 | xargs -0 -IX cp -v X $(NV_KERNEL_MODULES_TARGET_DIR)

kernel-tests: kmodules FORCE
	@echo "Kernel space tests build"
	@echo "Tests at $(PRIVATE_TOPDIR)/vendor/nvidia/tegra/tests/linux/kernel_space_tests"
	+$(hide) $(kernel-make) M=$(PRIVATE_TOPDIR)/vendor/nvidia/tegra/tests/linux/kernel_space_tests
	find $(PRIVATE_TOPDIR)/vendor/nvidia/tegra/tests/linux/kernel_space_tests -name "*.ko" -print0 | xargs -0 -IX cp -v X $(NV_KERNEL_MODULES_TARGET_DIR)
	find $(PRIVATE_TOPDIR)/vendor/nvidia/tegra/tests/linux/kernel_space_tests -name "*.sh" -print0 | xargs -0 -IX cp -v X $(TARGET_OUT)/bin/
	+$(hide) $(kernel-make) M=$(PRIVATE_TOPDIR)/vendor/nvidia/tegra/tests/linux/kernel_space_tests clean
	find $(PRIVATE_TOPDIR)/vendor/nvidia/tegra/tests/linux/kernel_space_tests -name "modules.order" -print0 | xargs -0 -IX rm -rf X

# At this stage, BUILT_SYSTEMIMAGE in $TOP/build/core/Makefile has not
# yet been defined, so we cannot rely on it.
_systemimage_intermediates_kmodules := \
    $(call intermediates-dir-for,PACKAGING,systemimage)
BUILT_SYSTEMIMAGE_KMODULES := $(_systemimage_intermediates_kmodules)/system.img
NV_INSTALLED_SYSTEMIMAGE := $(PRODUCT_OUT)/system.img

# Unless we hardcode the list of kernel modules, we cannot create
# a proper dependency from systemimage to the kernel modules.
# If we decide to hardcode later on, BUILD_PREBUILT (or maybe
# PRODUCT_COPY_FILES) can be used for including the modules in the image.
# For now, let's rely on an explicit dependency.
$(BUILT_SYSTEMIMAGE_KMODULES): kmodules

# Following dependency is already defined in $TOP/build/core/Makefile,
# but for the sake of clarity let's re-state it here. This dependency
# causes following dependencies to be indirectly defined:
#   $(NV_INSTALLED_SYSTEMIMAGE): kmodules $(BUILT_KERNEL_TARGET)
# which will prevent too early creation of systemimage.
$(NV_INSTALLED_SYSTEMIMAGE): $(BUILT_SYSTEMIMAGE_KMODULES)

$(INSTALLED_KERNEL_TARGET): $(BUILT_KERNEL_TARGET) | $(ACP)
	$(copy-file-to-target)

# Kernel build also includes some drivers as kernel modules which are
# packaged inside system image. Therefore, for incremental builds,
# dependency from kernel to installed system image must be introduced,
# so that recompilation of kernel automatically updates also the
# drivers in system image to be flashed to the device.
kernel: $(INSTALLED_KERNEL_TARGET) kmodules $(NV_INSTALLED_SYSTEMIMAGE)

kernel-%: | $(NV_KERNEL_INTERMEDIATES_DIR)
	$(hide) $(kernel-make) $*

$(NV_KERNEL_INTERMEDIATES_DIR) $(NV_KERNEL_MODULES_TARGET_DIR):
	$(hide) mkdir -p $@

.PHONY: kernel kernel-% kernel-tests kmodules

# Set private variables for all builds. TODO: Why?
kernel kernel-% kernel-tests kmodules $(dotconfig) $(BUILT_KERNEL_TARGET): PRIVATE_SRC_PATH := $(KERNEL_PATH)
kernel kernel-% kernel-tests kmodules $(dotconfig) $(BUILT_KERNEL_TARGET): PRIVATE_TOPDIR := $(CURDIR)

endif
# of ifneq ($(TARGET_NO_KERNEL),true)

# FIXME: This should be moved to a file of its own.
# TODO: This may not be what we want.
.PHONY: dev
dev: droidcore
ifneq ($(NO_ROOT_DEVICE),)
	device/nvidia/common/generate_nvtest_ramdisk.sh $(TARGET_PRODUCT) $(TARGET_BUILD_TYPE)
endif
