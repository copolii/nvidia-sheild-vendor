ifneq (, $(findstring 3., $(PLATFORM_VERSION)))
    PLATFORM_IS_HONEYCOMB := 1
else
    PLATFORM_IS_ICECREAMSANDWICH := 1
endif
