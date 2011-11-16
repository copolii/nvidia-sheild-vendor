# NVIDIA Tegra2 "Whistler" development system
OUTDIR=$(get_build_var PRODUCT_OUT)

echo -n "Memory (1)512MB (2)1GB: "
read -t 10 MEMORYSIZE

# setup NVFLASH ODM Data
cp $TOP/$OUTDIR/flash_512MB.bct $TOP/$OUTDIR/flash.bct
export NVFLASH_ODM_DATA=0x2B080105

if [ "$MEMORYSIZE" = "2" ]; then
cp $TOP/$OUTDIR/flash_1GB.bct $TOP/$OUTDIR/flash.bct
export NVFLASH_ODM_DATA=0x3B080105
fi
