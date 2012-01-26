# NVIDIA Tegra3.5 "curacao_sim" development system
OUTDIR=$(get_build_var PRODUCT_OUT)

# setup FASTBOOT VENDOR ID
export FASTBOOT_VID=0x955

# FIXME: Add NvFlash support

cp $TOP/$OUTDIR/obj/EXECUTABLES/bootloader_intermediates/bootloader.bin $TOP/$OUTDIR/bootloader.bin

