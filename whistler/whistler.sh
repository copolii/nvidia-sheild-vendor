# NVIDIA Tegra2 "Whistler" development system
OUTDIR=$(get_abs_build_var PRODUCT_OUT)

echo -n "Enter Memory (1)AP20 512MB (2)AP20 1GB (3) AP25 1GB: " >&2
read -t 10 MEMORYSIZE

echo "\n"
# setup NVFLASH ODM Data
cp $OUTDIR/flash_512MB.bct $OUTDIR/flash.bct
_NVFLASH_ODM_DATA=0x2B080105

if [ "$MEMORYSIZE" = "2" ]; then
cp $OUTDIR/flash_1GB.bct $OUTDIR/flash.bct
_NVFLASH_ODM_DATA=0x3B080105
fi

if [ "$MEMORYSIZE" = "3" ]; then
cp $OUTDIR/flash_AP25_1GB.bct $OUTDIR/flash.bct
_NVFLASH_ODM_DATA=0x3B080105
fi

if [ "$ODMDATA_OVERRIDE" ]; then
    export NVFLASH_ODM_DATA=$ODMDATA_OVERRIDE
else
    export NVFLASH_ODM_DATA=$_NVFLASH_ODM_DATA
fi
