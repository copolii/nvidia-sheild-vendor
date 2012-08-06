#
# Copyright (c) 2012, NVIDIA CORPORATION.  All rights reserved.
#
# NVIDIA Corporation and its licensors retain all intellectual property
# and proprietary rights in and to this software, related documentation
# and any modifications thereto.  Any use, reproduction, disclosure or
# distribution of this software and related documentation without an express
# license agreement from NVIDIA Corporation is strictly prohibited.
#

# NVIDIA Tegra3 "Enterprise" development system
OUTDIR=$(get_abs_build_var PRODUCT_OUT)
echo "DEBUG: PRODUCT_OUT = $OUTDIR"

# setup FASTBOOT VENDOR ID
export FASTBOOT_VID=0x955

if [ "$ENTERPRISE_A01" ]; then
    cp $OUTDIR/flash_a01.bct $OUTDIR/flash.bct
    cp $OUTDIR/bct_a01.cfg $OUTDIR/bct.cfg
    _NVFLASH_ODM_DATA=0x3009A000
elif [ "$ENTERPRISE_A03" -o "$ENTERPRISE_A04" ]; then
    cp $OUTDIR/flash_a03.bct $OUTDIR/flash.bct
    cp $OUTDIR/bct_a03.cfg $OUTDIR/bct.cfg
    _NVFLASH_ODM_DATA=0x4009A018
else
    cp $OUTDIR/flash_a02.bct $OUTDIR/flash.bct
    cp $OUTDIR/bct_a02.cfg $OUTDIR/bct.cfg
    _NVFLASH_ODM_DATA=0x3009A000
fi

# Set ODM_DATA for 768MB SDRAM
if [ "$ODMDATA_OVERRIDE" ]; then
    export NVFLASH_ODM_DATA=$ODMDATA_OVERRIDE
else
    export NVFLASH_ODM_DATA=$_NVFLASH_ODM_DATA
fi

# Indicate MDM partition is to be back-up/restore:
export enterprise_MDM_PARTITION="yes"
