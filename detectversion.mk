ifneq (,$(filter 2.%,$(PLATFORM_VERSION)))
  PLATFORM_IS_GINGERBREAD := YES
else ifneq (,$(filter 3.%,$(PLATFORM_VERSION)))
  PLATFORM_IS_HONEYCOMB := YES
else
  $(warning PLATFORM_VERSION = $(PLATFORM_VERSION) is unknown))
endif
