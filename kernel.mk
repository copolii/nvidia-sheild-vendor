#
# Linux kernel and loadable kernel modules
#
ifneq ($(TARGET_NO_KERNEL),true)

KERNEL_PATH ?= kernel

#kernel_version := $(strip $(shell head $(KERNEL_PATH)/Makefile | \
#	grep "SUBLEVEL =" | cut -d= -f2))

ifeq ($(TARGET_TEGRA_VERSION),ap20)
    TARGET_KERNEL_CONFIG ?= tegra_android_defconfig
else
ifeq ($(TARGET_TEGRA_VERSION),t30)
    TARGET_KERNEL_CONFIG ?= tegra3_android_defconfig
endif
endif

# Tegra platforms that have their own defconfig file
TEGRA_PLATFORM_DEFCONFIGS := aruba2 cardhu enterprise whistler

TEGRA_PLATFORM_DEFCONFIGS += curacao curacao_sim


ifeq (,$(filter-out $(TEGRA_PLATFORM_DEFCONFIGS),$(TARGET_PRODUCT)))
    CONFIG_NAME := tegra_$(TARGET_PRODUCT)_android_defconfig
    CONFIG_PATH := $(KERNEL_PATH)/arch/$(TARGET_ARCH)/configs/$(CONFIG_NAME)
    ifeq ($(wildcard $(CONFIG_PATH)),$(CONFIG_PATH))
        TARGET_KERNEL_CONFIG := $(CONFIG_NAME)
    endif
endif

ifeq ($(TARGET_KERNEL_CONFIG),)
    $(error Could not find kernel defconfig for board)
endif

_kernel_intermediates := $(TARGET_OUT_INTERMEDIATES)/KERNEL
dotconfig := $(_kernel_intermediates)/.config

KERNEL_EXTRA_ARGS=
OS=$(shell uname)
ifeq ($(OS),Darwin)
  # bring in our elf.h
  KERNEL_EXTRA_ARGS=HOST_EXTRACFLAGS=-I$(TOP)/../vendor/nvidia/tegra/core-private/include\ -DKBUILD_NO_NLS
  HOSTTYPE=darwin-x86
endif

ifeq ($(OS),Linux)
  HOSTTYPE=linux-x86
endif

# We should rather use CROSS_COMPILE=$(PRIVATE_TOPDIR)/$(TARGET_TOOLS_PREFIX).
define kernel-make
$(MAKE) -C $(PRIVATE_SRC_PATH) \
    ARCH=$(TARGET_ARCH) \
    CROSS_COMPILE=$(PRIVATE_TOPDIR)/prebuilt/$(HOSTTYPE)/toolchain/arm-eabi-4.4.3/bin/arm-eabi- \
    O=$(PRIVATE_TOPDIR)/$(PRIVATE_KBUILD_OUT) $(KERNEL_EXTRA_ARGS) \
    $(if $(SHOW_COMMANDS),V=1)
endef

BUILT_KERNEL_TARGET := $(_kernel_intermediates)/arch/$(TARGET_ARCH)/boot/zImage

$(dotconfig): $(KERNEL_PATH)/arch/$(TARGET_ARCH)/configs/$(TARGET_KERNEL_CONFIG)
	@echo "Kernel config"
	@mkdir -p $(PRIVATE_KBUILD_OUT)
	$(hide) $(kernel-make) $(TARGET_KERNEL_CONFIG)
ifeq ($(SECURE_OS_BUILD),y)
	@echo "SecureOS enabled kernel"
	$(KERNEL_PATH)/scripts/config --file $(dotconfig) --enable TRUSTED_FOUNDATIONS
endif

# TODO: figure out a way of not forcing kernel & module builds.
# + in front of kernel-make will enable job control (parallelization).
$(BUILT_KERNEL_TARGET): $(dotconfig) FORCE
	@echo "Kernel build"
	@mkdir -p $(PRIVATE_KBUILD_OUT)
	+$(hide) $(kernel-make) zImage

# This will add all kernel modules we build for inclusion the system
# image - no blessing takes place.
kmodules: $(BUILT_KERNEL_TARGET) FORCE
	@echo "Kernel modules build"
	+$(hide) $(kernel-make) modules
	mkdir -p $(TARGET_OUT)/lib/modules
	find $(PRIVATE_TOPDIR)/$(PRIVATE_KBUILD_OUT) -name "*.ko" -print0 | xargs -0 -IX cp -v X $(TARGET_OUT)/lib/modules/

kernel-tests: kmodules FORCE
	@echo "Kernel space tests build"
	@echo "Tests at $(PRIVATE_TOPDIR)/vendor/nvidia/tegra/tests/linux/kernel_space_tests"
	+$(hide) $(kernel-make) M=$(PRIVATE_TOPDIR)/vendor/nvidia/tegra/tests/linux/kernel_space_tests
	find $(PRIVATE_TOPDIR)/vendor/nvidia/tegra/tests/linux/kernel_space_tests -name "*.ko" -print0 | xargs -0 -IX cp -v X $(TARGET_OUT)/lib/modules/
	+$(hide) $(kernel-make) M=$(PRIVATE_TOPDIR)/vendor/nvidia/tegra/tests/linux/kernel_space_tests clean
	find $(PRIVATE_TOPDIR)/vendor/nvidia/tegra/tests/linux/kernel_space_tests -name "modules.order" -print0 | xargs -0 -IX rm -rf X

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

.PHONY: kernel kernel-% kernel-tests kmodules

# Set private variables for all builds. TODO: Why?
kernel kernel-% kernel-tests kmodules $(dotconfig) $(BUILT_KERNEL_TARGET): PRIVATE_SRC_PATH := $(KERNEL_PATH)
kernel kernel-% kernel-tests kmodules $(dotconfig) $(BUILT_KERNEL_TARGET): PRIVATE_KBUILD_OUT := $(TARGET_OUT_INTERMEDIATES)/KERNEL
kernel kernel-% kernel-tests kmodules $(dotconfig) $(BUILT_KERNEL_TARGET): PRIVATE_TOPDIR := $(shell pwd)

endif
# of ifneq ($(TARGET_NO_KERNEL),true)

# FIXME: This should be moved to a file of its own.
# TODO: This may not be what we want.
.PHONY: dev
dev: droidcore
ifneq ($(NO_ROOT_DEVICE),)
  ifeq ($(TARGET_BOARD_PLATFORM_TYPE),simulation)
	device/nvidia/common/generate_full_filesystem.sh
  else
	device/nvidia/common/generate_nvtest_ramdisk.sh $(TARGET_PRODUCT) $(TARGET_BUILD_TYPE)
  endif
endif
