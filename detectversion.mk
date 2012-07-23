PLATFORM_IS_JELLYBEAN := 1

ifneq (, $(findstring 3., $(PLATFORM_VERSION)))
  ifeq ($(BUILD_GOOGLETV),true)
     PLATFORM_IS_GTV_HC := 1
     PLATFORM_IS_JELLYBEAN :=
  endif
endif
