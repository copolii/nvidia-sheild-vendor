# NVIDIA Tegra3 "Cardhu" development system
OUTDIR=$(get_build_var PRODUCT_OUT)
echo "DEBUG: PRODUCT_OUT = $OUTDIR"

# setup FASTBOOT VENDOR ID
export FASTBOOT_VID=0x955

if [ ! "$BOARD_IS_PM269" ]
then
	# Set ODM_DATA for 1GB SDRAM
	export NVFLASH_ODM_DATA=0x40080105
	echo "Setting up NvFlash BCT for Cardhu with 1GB 533MHz DDR3 SDRAM......"
	cp $TEGRA_ROOT/../customers/nvidia-partner/cardhu/nvflash/E1186_Hynix_2GB_H5TC2G83BFR-PBA_533MHz_110316_sdmmc4_x8.bct $TOP/$OUTDIR/flash.bct
else
	# Set ODM_DATA for 1GB SDRAM
	export NVFLASH_ODM_DATA=0x40080105
	echo "Setting up NvFlash BCT for Cardhu with 1GB 533MHz DDR3 SDRAM......"
	cp $TEGRA_ROOT/../customers/nvidia-partner/cardhu/nvflash/PM269_Samsung_1GB_K4P8G304EC-FGC2_533MHz_110428_sdmmc4_x8.bct $TOP/$OUTDIR/flash.bct
fi

cp $TEGRA_ROOT/../customers/nvidia-partner/cardhu/nvflash/android_fastboot_emmc_full.cfg $TOP/$OUTDIR/flash.cfg
cp $TOP/$OUTDIR/obj/EXECUTABLES/bootloader_intermediates/bootloader.bin $TOP/$OUTDIR/bootloader.bin

