# NVIDIA Tegra3 "Kai" development system

# setup FASTBOOT VENDOR ID
export FASTBOOT_VID=0x955
# Set ODM_DATA for 1GB SDRAM
if [ "$ODMDATA_OVERRIDE" ]; then
    export NVFLASH_ODM_DATA=$ODMDATA_OVERRIDE
else
    export NVFLASH_ODM_DATA=0x20098000
fi

if [ "$T30_ON_T114" ]
then
        cp $OUTDIR/flash_noxusb.cfg $OUTDIR/flash.cfg
else
        cp $OUTDIR/flash_xusb.cfg $OUTDIR/flash.cfg
        cp $OUTDIR/flash_dalmore.bct $OUTDIR/flash.bct

fi
