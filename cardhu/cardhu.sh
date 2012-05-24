# NVIDIA Tegra3 "Cardhu" development system
OUTDIR=$(get_abs_build_var PRODUCT_OUT)
echo "DEBUG: PRODUCT_OUT = $OUTDIR"

# setup FASTBOOT VENDOR ID
export FASTBOOT_VID=0x955
# Set ODM_DATA for 1GB SDRAM
if [ "$ODMDATA_OVERRIDE" ]; then
    export NVFLASH_ODM_DATA=$ODMDATA_OVERRIDE
else
    export NVFLASH_ODM_DATA=0x40080000
fi

if [ "$BOARD_IS_PM269" ]
then
	cp $OUTDIR/flash_pm269.bct $OUTDIR/flash.bct
elif [ "$BOARD_IS_PM305" ]
then
	cp $OUTDIR/flash_pm305.bct $OUTDIR/flash.bct
else
	cp $OUTDIR/flash_cardhu.bct $OUTDIR/flash.bct
fi

