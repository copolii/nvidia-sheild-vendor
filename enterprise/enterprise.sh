# NVIDIA Tegra3 "Enterprise" development system
OUTDIR=$(get_abs_build_var PRODUCT_OUT)
echo "DEBUG: PRODUCT_OUT = $OUTDIR"

# setup FASTBOOT VENDOR ID
export FASTBOOT_VID=0x955

# Set ODM_DATA for 768MB SDRAM
if [ "$ODMDATA_OVERRIDE" ]; then
    export NVFLASH_ODM_DATA=$ODMDATA_OVERRIDE
else
    export NVFLASH_ODM_DATA=0x30098000
fi

if [ "$ENTERPRISE_A01" ]
then
    cp $OUTDIR/flash_a01.bct $OUTDIR/flash.bct
else
    cp $OUTDIR/flash_a02.bct $OUTDIR/flash.bct
fi

