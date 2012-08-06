#
# Copyright (c) 2012, NVIDIA CORPORATION.  All rights reserved.
#
# NVIDIA Corporation and its licensors retain all intellectual property
# and proprietary rights in and to this software, related documentation
# and any modifications thereto.  Any use, reproduction, disclosure or
# distribution of this software and related documentation without an express
# license agreement from NVIDIA Corporation is strictly prohibited.
#

# NVIDIA Tegra2 "Whistler" development system
OUTDIR=$(get_abs_build_var PRODUCT_OUT)

echo -n "Enter Memory (1)AP20 512MB (2)AP20 1GB (3) AP25 1GB: " >&2
read -t 10 MEMORYSIZE

echo "\n"
# setup NVFLASH ODM Data
cp $OUTDIR/flash_512MB.bct $OUTDIR/flash.bct
cp $OUTDIR/bct_512MB.cfg $OUTDIR/bct.cfg
_NVFLASH_ODM_DATA=0x2B080105

if [ "$MEMORYSIZE" = "2" ]; then
cp $OUTDIR/flash_1GB.bct $OUTDIR/flash.bct
cp $OUTDIR/bct_1GB.cfg $OUTDIR/bct.cfg
_NVFLASH_ODM_DATA=0x3B080105
fi

if [ "$MEMORYSIZE" = "3" ]; then
cp $OUTDIR/flash_AP25_1GB.bct $OUTDIR/flash.bct
cp $OUTDIR/bct_AP25_1GB.cfg $OUTDIR/bct.cfg
_NVFLASH_ODM_DATA=0x3B080105
fi

if [ "$ODMDATA_OVERRIDE" ]; then
    export NVFLASH_ODM_DATA=$ODMDATA_OVERRIDE
else
    export NVFLASH_ODM_DATA=$_NVFLASH_ODM_DATA
fi

# Indicate MDM partition is to be back-up/restore:
export whistler_MDM_PARTITION="yes"
