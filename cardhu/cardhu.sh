#
# Copyright (c) 2012, NVIDIA CORPORATION.  All rights reserved.
#
# NVIDIA Corporation and its licensors retain all intellectual property
# and proprietary rights in and to this software, related documentation
# and any modifications thereto.  Any use, reproduction, disclosure or
# distribution of this software and related documentation without an express
# license agreement from NVIDIA Corporation is strictly prohibited.
#

# NVIDIA Tegra3 "Cardhu" development system
OUTDIR=$(get_abs_build_var PRODUCT_OUT)
echo "DEBUG: PRODUCT_OUT = $OUTDIR"

# setup FASTBOOT VENDOR ID
export FASTBOOT_VID=0x955
# Set ODM_DATA for 1GB SDRAM
if [ "$ODMDATA_OVERRIDE" ]; then
    export NVFLASH_ODM_DATA=$ODMDATA_OVERRIDE
else
    export NVFLASH_ODM_DATA=0x40080000
fi

if [ "$BOARD_IS_PM269" ]
then
	cp $OUTDIR/flash_pm269.bct $OUTDIR/flash.bct
	cp $OUTDIR/bct_pm269.cfg $OUTDIR/bct.cfg
elif [ "$BOARD_IS_PM305" ]
then
	cp $OUTDIR/flash_pm305.bct $OUTDIR/flash.bct
	cp $OUTDIR/bct_pm305.cfg $OUTDIR/bct.cfg
else
	cp $OUTDIR/flash_cardhu.bct $OUTDIR/flash.bct
	cp $OUTDIR/bct_cardhu.cfg $OUTDIR/bct.cfg
fi

