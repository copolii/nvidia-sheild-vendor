###############################################################################
#
# Copyright (c) 2010-2012, NVIDIA CORPORATION.  All rights reserved.
#
# NVIDIA CORPORATION and its licensors retain all intellectual property
# and proprietary rights in and to this software, related documentation
# and any modifications thereto.  Any use, reproduction, disclosure or
# distribution of this software and related documentation without an express
# license agreement from NVIDIA CORPORATION is strictly prohibited.
#
###############################################################################

function _gethosttype()
{
    H=`uname`
    if [ "$H" == Linux ]; then
        HOSTTYPE="linux-x86"
    fi

    if [ "$H" == Darwin ]; then
        HOSTTYPE="darwin-x86"
        export HOST_EXTRACFLAGS="-I$(gettop)/vendor/nvidia/tegra/core-private/include"
    fi
}

function _getnumcpus ()
{
    # if we happen to not figure it out, default to 2 CPUs
    NUMCPUS=2

    _gethosttype

    if [ "$HOSTTYPE" == "linux-x86" ]; then
        NUMCPUS=`cat /proc/cpuinfo | grep processor | wc -l`
    fi

    if [ "$HOSTTYPE" == "darwin-x86" ]; then
        NUMCPUS=`sysctl -n hw.activecpu`
    fi
}

function _ktoolchain()
{
    local build_id=$(get_build_var BUILD_ID)
    if [[ "${build_id}" =~ ^J ]]; then
        echo "CROSS_COMPILE=$T/prebuilts/gcc/$HOSTTYPE/arm/arm-eabi-4.6/bin/arm-eabi-"
    else
        echo "CROSS_COMPILE=$T/prebuilt/$HOSTTYPE/toolchain/arm-eabi-4.4.3/bin/arm-eabi-"
    fi
}

function ksetup()
{
    T=$(gettop)
    if [ ! "$T" ]; then
        echo "Couldn't locate the top of the tree. Try setting TOP." >&2
        return 1
    fi

    local SRC=${KERNEL_PATH:-"$T/kernel"}
    if [ $# -lt 1 ] ; then
        echo "Usage: ksetup <defconfig> <path>"
        return 1
    fi

    if [ $# -gt 1 ] ; then
        SRC="$2"
    fi

    if [ ! -d "$SRC" ] ; then
        echo "$SRC not found."
        return 1
    fi
    _gethosttype

    local TOOLS=$(get_build_var TARGET_TOOLS_PREFIX)
    local ARCHITECTURE=$(get_build_var TARGET_ARCH)
    local INTERMEDIATES=$(get_build_var TARGET_OUT_INTERMEDIATES)
    local KOUT="$T/$INTERMEDIATES/KERNEL"
    local CROSS=$(_ktoolchain)
    local KARCH="ARCH=$ARCHITECTURE"
    local SECURE_OS_BUILD=$(get_build_var SECURE_OS_BUILD)

    echo "mkdir -p $KOUT"
    echo "make -C $SRC $KARCH $CROSS O=$KOUT $1"
    (cd $T && mkdir -p $KOUT ; make -C $SRC $KARCH $CROSS O=$KOUT $1)

    if [ "$SECURE_OS_BUILD" == "y" ]; then
        $SRC/scripts/config --file $KOUT/.config --enable TRUSTED_FOUNDATIONS
    fi
    if [ "$NVIDIA_KERNEL_COVERAGE_ENABLED" == "1" ]; then
        echo "Explicitly enabling coverage support in kernel config on user request"
        $SRC/scripts/config --file $KOUT/.config \
            --enable DEBUG_FS \
            --enable GCOV_KERNEL \
            --enable GCOV_TOOLCHAIN_IS_ANDROID \
            --disable GCOV_PROFILE_ALL
    fi
}

function kconfig()
{
   T=$(gettop)
    if [ ! "$T" ]; then
        echo "Couldn't locate the top of the tree. Try setting TOP." >&2
        return 1
    fi

    local SRC=${KERNEL_PATH:-"$T/kernel"}
    if [ -d "$1" ] ; then
        SRC="$1"
        shift 1
    fi

    if [ ! -d "$SRC" ] ; then
        echo "$SRC not found."
        return 1
    fi

    _gethosttype

    local TOOLS=$(get_build_var TARGET_TOOLS_PREFIX)
    local ARCHITECTURE=$(get_build_var TARGET_ARCH)
    local INTERMEDIATES=$(get_build_var TARGET_OUT_INTERMEDIATES)
    local KOUT="O=$T/$INTERMEDIATES/KERNEL"
    local CROSS=$(_ktoolchain)
    local KARCH="ARCH=$ARCHITECTURE"

    echo "make -C $SRC $KARCH $CROSS $KOUT menuconfig"
    (cd $T && make -C $SRC $KARCH $CROSS $KOUT menuconfig)
}

function ksavedefconfig()
{
    T=$(gettop)
    if [ ! "$T" ]; then
        echo "Couldn't locate the top of the tree. Try setting TOP." >&2
        return 1
    fi

    local SRC=${KERNEL_PATH:-"$T/kernel"}
    if [ $# -lt 1 ] ; then
        echo "Usage: ksavedefconfig <defconfig> [kernelpath]"
        return 1
    fi

    if [ $# -gt 1 ] ; then
        SRC="$2"
    fi

    if [ ! -d "$SRC" ] ; then
        echo "$SRC not found."
        return 1
    fi

    _gethosttype

    local TOOLS=$(get_build_var TARGET_TOOLS_PREFIX)
    local ARCHITECTURE=$(get_build_var TARGET_ARCH)
    local INTERMEDIATES=$(get_build_var TARGET_OUT_INTERMEDIATES)
    local KOUT="$T/$INTERMEDIATES/KERNEL"
    local CROSS=$(_ktoolchain)
    local KARCH="ARCH=$ARCHITECTURE"

    # make a backup of the current configuration
    cp $KOUT/.config $KOUT/.config.backup

    # CONFIG_TRUSTED_FOUNDATIONS is turned on in kernel.mk or ksetup rather than defconfig
    # don't store coverage setup to defconfig
    $SRC/scripts/config --file $KOUT/.config \
        --disable TRUSTED_FOUNDATIONS \
        --disable GCOV_KERNEL

    echo "make -C $SRC $KARCH $CROSS O=$KOUT savedefconfig"
    (cd $T && make -C $SRC $KARCH $CROSS O=$KOUT savedefconfig &&
        cp $KOUT/defconfig $SRC/arch/arm/configs/$1)

    # restore configuration from backup
    rm $KOUT/.config
    mv $KOUT/.config.backup $KOUT/.config
}

function krebuild()
{
    T=$(gettop)
    if [ ! "$T" ]; then
        echo "Couldn't locate the top of the tree. Try setting TOP." >&2
        return 1
    fi

    local SRC=${KERNEL_PATH:-"$T/kernel"}
    if [ -d "$1" ] ; then
        SRC="$1"
        shift 1
    fi

    if [ ! -d "$SRC" ] ; then
        echo "$SRC not found."
        return 1
    fi

    _gethosttype
    _getnumcpus

    local OUTDIR=$(get_build_var PRODUCT_OUT)
    local TOOLS=$(get_build_var TARGET_TOOLS_PREFIX)
    local ARCHITECTURE=$(get_build_var TARGET_ARCH)
    local INTERMEDIATES=$(get_build_var TARGET_OUT_INTERMEDIATES)
    local HOSTOUT=$(get_build_var HOST_OUT)
    local MKBOOTIMG=$T/$HOSTOUT/bin/mkbootimg
    local ZIMAGE=$T/$INTERMEDIATES/KERNEL/arch/arm/boot/zImage
    local RAMDISK=$T/$OUTDIR/ramdisk.img

    local KOUT="O=$T/$INTERMEDIATES/KERNEL"
    local CROSS=$(_ktoolchain)
    local KARCH="ARCH=$ARCHITECTURE"

    if [ ! -f "$RAMDISK" ]; then
        echo "Couldn't find $RAMDISK. Try setting TARGET_PRODUCT." >&2
        return 1
    fi

    echo "make -j$NUMCPUS -C $SRC $* $KARCH $CROSS $KOUT"
    (cd $T && make -j$NUMCPUS -C $SRC $* $KARCH $CROSS $KOUT)
    local ERR=$?

    if [ $ERR -ne 0 ] ; then
	return $ERR
    fi

    if [ -d "$T/$OUTDIR/modules" ] ; then
        rm -r $T/$OUTDIR/modules
    fi

    (mkdir -p $T/$OUTDIR/modules \
        && cd $T && make modules_install -C $SRC $KARCH $CROSS $KOUT INSTALL_MOD_PATH=$T/$OUTDIR/modules \
        && mkdir -p $T/$OUTDIR/system/lib/modules && cp -f `find $T/$OUTDIR/modules -name *.ko` $T/$OUTDIR/system/lib/modules \
        && $MKBOOTIMG --kernel $ZIMAGE --ramdisk $RAMDISK --output $T/$OUTDIR/boot.img )

    echo "$OUT/Boot.img created successfully."
}

# allow us to override Google defined functions to apply local fixes
# see: http://mivok.net/2009/09/20/bashfunctionoverrist.html
_save_function()
{
    local oldname=$1
    local newname=$2
    local code=$(declare -f ${oldname})
    eval "${newname}${code#${oldname}}"
}

#
# Unset variables known to break or harm the Android Build System
#
#  - CDPATH: breaks build
#    https://groups.google.com/forum/?fromgroups=#!msg/android-building/kW-WLoag0EI/RaGhoIZTEM4J
#
_save_function m  _google_m
function m()
{
    CDPATH= _google_m $*
}

_save_function mm _google_mm
function mm()
{
    CDPATH= _google_mm $*
}

function mp()
{
    _getnumcpus
    m -j$NUMCPUS $*
}

function mmp()
{
    _getnumcpus
    mm -j$NUMCPUS $*
}

function _flash()
{
    T=$(gettop)

    if [ ! "$T" ]; then
        echo "Couldn't locate the top of the tree.  Try setting TOP." >&2
        return 1
    fi

    # Get NVFLASH_ODM_DATA from the product specific shell script.
    local product=$(get_build_var TARGET_PRODUCT)
    if [ -f $T/vendor/nvidia/build/${product}/${product}.sh ]; then
        echo "run product script"
        . $T/vendor/nvidia/build/${product}/${product}.sh
    fi

    local OUTDIR=$(get_build_var PRODUCT_OUT)
    local HOSTOUT=$(get_build_var HOST_OUT)
    local FLASH_CMD="$T/$HOSTOUT/bin/nvflash"
    local NVFLASH_PATH="${FLASH_CMD}"
    local _PRODUCT_MDM_PARTITION="${product}_MDM_PARTITION"

    if [ "${!_PRODUCT_MDM_PARTITION}" == "yes" -a "${PRODUCT_MDM_PARTITION}" != "no" ] ; then
        # Read MDM partition for back-up:
        MDM_BACKUP_CMD="${NVFLASH_PATH} --read MDM MDM_${product}.img --bl bootloader.bin"
        # Remaining nvflash operations will be in resume mode:
        FLASH_CMD="${FLASH_CMD} --resume "
    fi

    if [ "${NVFLASH_BCT}" != "" ] ; then
        FLASH_CMD="$FLASH_CMD --bct ${NVFLASH_BCT} --setbct"
    else
        FLASH_CMD="$FLASH_CMD --bct flash.bct --setbct"
    fi
    if [ "${NVFLASH_ODM_DATA}" != "" ] ; then
        FLASH_CMD="$FLASH_CMD --odmdata ${NVFLASH_ODM_DATA}"
    fi
    FLASH_CMD="$FLASH_CMD --configfile flash.cfg"
    FLASH_CMD="$FLASH_CMD --create"
    # TODO: can this be removed?  See commit 63c25d2ea07972.
    [ "${NVFLASH_VERIFY}" ] && FLASH_CMD="$FLASH_CMD --verifypart -1"
    FLASH_CMD="$FLASH_CMD --bl bootloader.bin"
    [ "$*" != "" ] && FLASH_CMD="$FLASH_CMD $*"

    if [ "${!_PRODUCT_MDM_PARTITION}" == "yes" -a "${PRODUCT_MDM_PARTITION}" != "no" ] ; then
        # Restore MDM partition:
        MDM_RESTORE_CMD="${NVFLASH_PATH} --resume --download MDM MDM_${product}.img --bl bootloader.bin"
        # Update full flash cmd:
        FLASH_CMD="${MDM_BACKUP_CMD} && ${FLASH_CMD} && ${MDM_RESTORE_CMD}"
    fi

    FLASH_CMD="$FLASH_CMD --go"

    echo $FLASH_CMD
}

function fboot()
{
    T=$(gettop)

    if [ ! "$T" ]; then
        echo "Couldn't locate the top of the tree. Try setting TOP." >&2
        return 1
    fi
    local INTERMEDIATES=$(get_build_var TARGET_OUT_INTERMEDIATES)
    local OUTDIR=$(get_build_var PRODUCT_OUT)
    local HOST_OUTDIR=$(get_build_var HOST_OUT)

    local ZIMAGE=$T/$INTERMEDIATES/KERNEL/arch/arm/boot/zImage
    local RAMDISK=$T/$OUTDIR/ramdisk.img
    local FASTBOOT=$T/$HOST_OUTDIR/bin/fastboot

    # Get Vendor ID (FASTBOOT_VID) from the product specific shell script.
    local product=$(get_build_var TARGET_PRODUCT)
    if [ -f $T/vendor/nvidia/build/${product}/${product}.sh ]; then
       . $T/vendor/nvidia/build/${product}/${product}.sh
    fi
    local vendor_id
    vendor_id=${FASTBOOT_VID:-"0x955"}

    if [ ! "$FASTBOOT" ]; then
        echo "Couldn't find $FASTBOOT." >&2
        return 1
    fi

    if [ $# != 0 ] ; then
        CMD=$*
    else
        if [ ! -f  "$ZIMAGE" ]; then
            echo "Couldn't find $ZIMAGE. Try setting TARGET_PRODUCT." >&2
            return 1
        fi
        if [ ! -f "$RAMDISK" ]; then
            echo "Couldn't find $RAMDISK. Try setting TARGET_PRODUCT." >&2
            return 1
        fi
        CMD="-i $vendor_id boot $ZIMAGE $RAMDISK"
    fi

    echo "sudo $FASTBOOT $CMD"
    (eval sudo $FASTBOOT $CMD)
}

function fflash()
{
    T=$(gettop)

    if [ ! "$T" ]; then
        echo "Couldn't locate the top of the tree. Try setting TOP." >&2
        return 1
    fi
    local OUTDIR=$(get_build_var PRODUCT_OUT)
    local HOST_OUTDIR=$(get_build_var HOST_OUT)

    local BOOTIMAGE=$T/$OUTDIR/boot.img
    local SYSTEMIMAGE=$T/$OUTDIR/system.img
    local FASTBOOT=$T/$HOST_OUTDIR/bin/fastboot

    # Get Vendor ID (FASTBOOT_VID) from the product specific shell script.
    local product=$(get_build_var TARGET_PRODUCT)
    if [ -f $T/vendor/nvidia/build/${product}/${product}.sh ]; then
       . $T/vendor/nvidia/build/${product}/${product}.sh
    fi
    local vendor_id
    vendor_id=${FASTBOOT_VID:-"0x955"}

    if [ ! "$FASTBOOT" ]; then
        echo "Couldn't find $FASTBOOT." >&2
        return 1
    fi

    if [ $# != 0 ] ; then
        CMD=$*
    else
        if [ ! -f  "$BOOTIMAGE" ]; then
            echo "Couldn't find $BOOTIMAGE. Check your build for any error." >&2
            return 1
        fi
        if [ ! -f "$SYSTEMIMAGE" ]; then
            echo "Couldn't find $SYSTEMIMAGE. Check your build for any error." >&2
            return 1
        fi
        CMD="-i $vendor_id flash system $SYSTEMIMAGE flash boot $BOOTIMAGE reboot"
    fi

    echo "sudo $FASTBOOT $CMD"
    (sudo $FASTBOOT $CMD)
}

function flash()
{
    T=$(gettop)
    if [ ! "$T" ]; then
        echo "Couldn't locate the top of the tree.  Try setting TOP." >&2
        return 1
    fi

    local OUTDIR=$(get_build_var PRODUCT_OUT)

    local FLASH_CMD="$(_flash $* | tail -1)"
    echo $FLASH_CMD

    (cd $T/$OUTDIR && eval sudo $FLASH_CMD)
}

# Inform user about the new name of the function.  This should be removed
# after a transition period (around June 2011).
function nvflash()
{
    echo "Shell function \"nvflash\" is obsolete, please use \"flash\" instead." >&2
}

function _nvflash_sh()
{
    T=$(gettop)
    if [ ! "$T" ]; then
        echo "Couldn't locate the top of the tree.  Try setting TOP." >&2
        return 1
    fi

    local OUTDIR=$(get_build_var PRODUCT_OUT)
    local FLASH_CMD=$(_flash | tail -1)
    FLASH_CMD="../../../../${FLASH_CMD#${T}/}"

    local FLASH_SH="$T/$OUTDIR/nvflash.sh"

    echo "#!/bin/bash" > $FLASH_SH
    echo $FLASH_CMD >> $FLASH_SH

    chmod 755 $FLASH_SH
}

function adbserver()
{
    f=$(pgrep adb)
    if [ $? -ne 0 ]; then
        ADB=$(which adb)
        echo "Starting adb server.."
	sudo ${ADB} start-server
    fi
}

function nvlog()
{
    T=$(gettop)
    if [ ! "$T" ]; then
	echo "Couldn't locate the top of the tree.  Try setting TOP." >&2
	return 1
    fi
    adbserver
    adb logcat | $T/vendor/nvidia/build/asymfilt.py
}

function stayon()
{
    adbserver
    adb shell "svc power stayon true && echo main >/sys/power/wake_lock"
}

# Remove TEGRA_ROOT, no longer required and should never be used.

if [ -n "$TEGRA_ROOT" ]; then
    echo "WARNING: TEGRA_ROOT env variable is set to: $TEGRA_ROOT"
    echo "This variable has been superseded by TEGRA_TOP."
    echo "Removing TEGRA_ROOT from environment"
    unset TEGRA_ROOT
fi

if [ -f $HOME/lib/android/envsetup.sh ]; then
    echo including $HOME/lib/android/envsetup.sh
    .  $HOME/lib/android/envsetup.sh
fi

if [ -d $(gettop)/vendor/nvidia/proprietary_src ]; then
    export TEGRA_TOP=$(gettop)/vendor/nvidia/proprietary_src
elif [ -d $(gettop)/vendor/nvidia/tegra ]; then
    export TEGRA_TOP=$(gettop)/vendor/nvidia/tegra
else
    echo "WARNING: Unable to set TEGRA_TOP environment variable."
    echo "Valid TEGRA_TOP directories are:"
    echo "$(gettop)/vendor/nvidia/proprietary_src"
    echo "$(gettop)/vendor/nvidia/tegra"
    echo "At least one of them should exist."
    echo "Please make sure your Android source tree is setup correctly."
    # This script will be sourced, so use return instead of exit
    return 1
fi

if [ -f $TOP/vendor/pdk/mini_armv7a_neon/mini_armv7a_neon-userdebug/platform/platform.zip ]; then
    export PDK_FUSION_PLATFORM_ZIP=$TOP/vendor/pdk/mini_armv7a_neon/mini_armv7a_neon-userdebug/platform/platform.zip
fi

if [ `uname` == "Darwin" ]; then
    if [[ -n $FINK_ROOT && -z $GNU_COREUTILS ]]; then
        export GNU_COREUTILS=${FINK_ROOT}/lib/coreutils/bin
    elif [[ -n $MACPORTS_ROOT && -z $GNU_COREUTILS ]]; then
        export GNU_COREUTILS=${MACPORTS_ROOT}/local/libexec/gnubin
    elif [[ -n $GNU_COREUTILS ]]; then
        :
    else
        echo "Cannot find GNU coreutils. Please set either GNU_COREUTILS, FINK_ROOT or MACPORTS_ROOT."
    fi
fi

# Disabled in early development phase.
#if [ -f $TEGRA_TOP/tmake/scripts/envsetup.sh ]; then
#    _nvsrc=$(echo ${TEGRA_TOP}|colrm 1 `echo $TOP|wc -c`)
#    echo "including ${_nvsrc}/tmake/scripts/envsetup.sh"
#    . $TEGRA_TOP/tmake/scripts/envsetup.sh
#fi

if uname -m|grep '64$' > /dev/null; then
    _nvm_wrap=$TEGRA_TOP/core-private/tools/nvm_wrap/prebuilt/`uname | tr '[:upper:]' '[:lower:]'`-x86/nvm_wrap
    if [ -f "$_nvm_wrap" ]; then
        export ANDROID_BUILD_SHELL=$_nvm_wrap
    fi
fi
