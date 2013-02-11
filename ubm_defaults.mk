# Temporary defines to enable TXXX support.
# Remove once these flags have been cleaned up from the tree.
# NVUB_SUPPORTS_TXXX = 1
# LOCAL_CFLAGS += -DNVUB_SUPPORTS_TXXX=1

# Temporary define to enable T13X code
NVUB_SUPPORTS_T132 ?= 1
ifeq ($(NVUB_SUPPORTS_T132),1)
LOCAL_CFLAGS += -DNVUB_SUPPORTS_T132=1
else
LOCAL_CFLAGS += -DNVUB_SUPPORTS_T132=0
endif
