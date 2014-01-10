# Temporary defines to enable TXXX support.
# Remove once these flags have been cleaned up from the tree.
# NVUB_SUPPORTS_TXXX = 1
# NVUB_SUPPORTS_FLAG_LIST += NVUB_SUPPORTS_TXXX=$(NVUB_SUPPORTS_TXXX)
# LOCAL_CFLAGS += -DNVUB_SUPPORTS_TXXX=$(NVUB_SUPPORTS_TXXX)
#
include $(NVIDIA_UBM_ENABLE)

# Flag list to forward UBM flags to external make instance
NVUB_SUPPORTS_FLAG_LIST :=

#
# Section for next chip to merge
#
# This must be removed manually after all flaggings have been removed from code
#

ifeq ($(NVUB_UNIFIED_BRANCHING_ENABLED),1)
endif
