# NVIDIA Tegra4 "Bonaire" development system
echo "DEBUG: Entering $TOP/vendor/nvidia/build/bonaire/bonaire.sh"

OUTDIR=$(get_build_var PRODUCT_OUT)
echo "DEBUG: PRODUCT_OUT = $OUTDIR"

# setup FASTBOOT VENDOR ID
export FASTBOOT_VID=0x955

if [ ! "$FPGA_HAS_LPDDR2" ]
then
    echo "Setting up NvFlash BCT for Bonaire with DDR3 SDRAM......"
    cp $TEGRA_TOP/customers/nvidia/bonaire/nvflash/bonaire_13Mhz_H5TQ1G83BFR-H9C_13Mhz_1GB_emmc_H26M42001EFR_x8.bct $TOP/$OUTDIR/flash.bct
    cp $TEGRA_TOP/customers/nvidia/bonaire/nvflash/android_fastboot_emmc_full.cfg                                   $TOP/$OUTDIR/flash.cfg
    export NVFLASH_ODM_DATA=0x40080105
else
    echo "Setting up NvFlash BCT for Bonaire with LPDDR2 SDRAM......"
    cp $TEGRA_TOP/customers/nvidia/bonaire/nvflash/bonaire_13Mhz_H8TBR00Q0MLR_13Mhz_256MB_emmc_H26M42001EFR_x8.bct  $TOP/$OUTDIR/flash.bct
    cp $TEGRA_TOP/customers/nvidia/bonaire/nvflash/android_fastboot_emmc_full.cfg                                   $TOP/$OUTDIR/flash.cfg
    export NVFLASH_ODM_DATA=0x10080105
fi

cp $TOP/$OUTDIR/obj/EXECUTABLES/bootloader_intermediates/bootloader.bin $TOP/$OUTDIR/bootloader.bin

echo "DEBUG: Leaving $TOP/vendor/nvidia/build/bonaire/bonaire.sh"

