# NVIDIA Tegra3 "Kai" development system

# setup FASTBOOT VENDOR ID
export FASTBOOT_VID=0x955
# Set ODM_DATA for 1GB SDRAM
if [ ! "$NVFLASH_ODM_DATA" ]; then
    export NVFLASH_ODM_DATA=0x40098105
fi

