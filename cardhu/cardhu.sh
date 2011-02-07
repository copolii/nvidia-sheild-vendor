# NVIDIA Tegra3 "Cardhu" development system
local OUTDIR=$(get_build_var PRODUCT_OUT)
echo "DEBUG: PRODUCT_OUT = $OUTDIR"

# setup FASTBOOT VENDOR ID
export FASTBOOT_VID=0x955

# Set ODM_DATA for 2GB SDRAM
export NVFLASH_ODM_DATA=0x80080105

echo "Setting up NvFlash BCT for Cardhu with 2GB 677MHz DDR3 SDRAM......"
cp $TEGRA_ROOT/../customers/nvidia/cardhu/nvflash/E1187_Hynix_2GB_H5TC2G83BFR-PBA_667MHz_20110203_2316.bct $TOP/$OUTDIR/flash.bct
cp $TEGRA_ROOT/../customers/nvidia/cardhu/nvflash/android_fastboot_emmc_full.cfg $TOP/$OUTDIR/flash.cfg
cp $TOP/$OUTDIR/obj/EXECUTABLES/bootloader_intermediates/bootloader.bin $TOP/$OUTDIR/bootloader.bin

