# NVIDIA Tegra4 "Curacao" development system
echo "DEBUG: Entering $TOP/vendor/nvidia/build/curacao/curacao.sh"

OUTDIR=$(get_build_var PRODUCT_OUT)
echo "DEBUG: PRODUCT_OUT = $OUTDIR"

# setup FASTBOOT VENDOR ID
export FASTBOOT_VID=0x955

if [ ! "$FPGA_HAS_LPDDR2" ]
then
    echo "Setting up NvFlash BCT for Curacao with DDR3 SDRAM......"
    export NVFLASH_ODM_DATA=0x400c0105
else
    echo "Setting up NvFlash BCT for Curacao with LPDDR2 SDRAM......"
    export NVFLASH_ODM_DATA=0x100c0105
fi

cp $TOP/$OUTDIR/obj/EXECUTABLES/bootloader_intermediates/bootloader.bin $TOP/$OUTDIR/bootloader.bin

echo "DEBUG: Leaving $TOP/vendor/nvidia/build/curacao/curacao.sh"

