# NVIDIA Tegra3 "Pluto" development system

# setup FASTBOOT VENDOR ID
export FASTBOOT_VID=0x955
if [ "$ODMDATA_OVERRIDE" ]; then
    export NVFLASH_ODM_DATA=$ODMDATA_OVERRIDE
else
    export NVFLASH_ODM_DATA=0x20098000
fi

