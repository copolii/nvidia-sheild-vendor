# NVIDIA Tegra148 "ceres" development system
OUTDIR=$(get_abs_build_var PRODUCT_OUT)
echo "DEBUG: PRODUCT_OUT = $OUTDIR"

# setup FASTBOOT VENDOR ID
export FASTBOOT_VID=0x955
# Set ODM_DATA for 2GB SDRAM
if [ "$ODMDATA_OVERRIDE" ]; then
    export NVFLASH_ODM_DATA=$ODMDATA_OVERRIDE
else
    export NVFLASH_ODM_DATA=0x80098000
fi

export NVFLASH_BCT=flash_ceres_e1613.cfg
