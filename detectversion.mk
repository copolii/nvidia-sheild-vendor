PLATFORM_IS_JELLYBEAN := 1
ifeq ($(PLATFORM_VERSION),4.2)
PLATFORM_IS_JELLYBEAN_MR1 := 1
endif

ifneq (, $(findstring 3., $(PLATFORM_VERSION)))
  ifeq ($(BUILD_GOOGLETV),true)
     PLATFORM_IS_GTV_HC := 1
     PLATFORM_IS_JELLYBEAN :=
  endif
endif
