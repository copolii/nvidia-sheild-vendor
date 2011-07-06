# NVIDIA Tegra3 "Cardhu" development system
OUTDIR=$(get_build_var PRODUCT_OUT)
echo "DEBUG: PRODUCT_OUT = $OUTDIR"

# setup FASTBOOT VENDOR ID
export FASTBOOT_VID=0x955
# Set ODM_DATA for 1GB SDRAM
export NVFLASH_ODM_DATA=0x40080105

if [ "$BOARD_IS_PM269" ]
then
	cp $TOP/$OUTDIR/flash_pm269.bct $TOP/$OUTDIR/flash.bct
else
	cp $TOP/$OUTDIR/flash_cardhu.bct $TOP/$OUTDIR/flash.bct
fi

cp $TEGRA_ROOT/../customers/nvidia-partner/cardhu/nvflash/android_fastboot_emmc_full.cfg $TOP/$OUTDIR/flash.cfg
cp $TOP/$OUTDIR/obj/EXECUTABLES/bootloader_intermediates/bootloader.bin $TOP/$OUTDIR/bootloader.bin

