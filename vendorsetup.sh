function _gethosttype()
{
    H=`uname`
    if [ "$H" == Linux ]; then
        HOSTTYPE="linux-x86"
    fi

    if [ "$H" == Darwin ]; then
        HOSTTYPE="darwin-x86"
        export HOST_EXTRACFLAGS="-I$TOP/vendor/nvidia/tegra/core-private/include"
    fi
}

function ksetup()
{
    T=$(gettop)
    if [ ! "$T" ]; then
        echo "Couldn't local the top of the tree. Try setting TOP." >&2
        return 1
    fi

    local SRC="$T/kernel"
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
    local CROSS="CROSS_COMPILE=$T/prebuilt/$HOSTTYPE/toolchain/arm-eabi-4.4.3/bin/arm-eabi-"
    local KARCH="ARCH=$ARCHITECTURE"

    echo "mkdir -p $KOUT"
    echo "make -C $SRC $KARCH $CROSS O=$KOUT $1"
    (cd $T && mkdir -p $KOUT ; make -C $SRC $KARCH $CROSS O=$KOUT $1)
}

function kconfig()
{
   T=$(gettop)
    if [ ! "$T" ]; then
        echo "Couldn't local the top of the tree. Try setting TOP." >&2
        return 1
    fi

    local SRC="$T/kernel"
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
    local CROSS="CROSS_COMPILE=$T/prebuilt/$HOSTTYPE/toolchain/arm-eabi-4.4.3/bin/arm-eabi-"
    local KARCH="ARCH=$ARCHITECTURE"

    echo "make -C $SRC $KARCH $CROSS $KOUT menuconfig"
    (cd $T && make -C $SRC $KARCH $CROSS $KOUT menuconfig)
}

function krebuild()
{
    T=$(gettop)
    if [ ! "$T" ]; then
        echo "Couldn't local the top of the tree. Try setting TOP." >&2
        return 1
    fi

    local SRC="$T/kernel"
    if [ -d "$1" ] ; then
        SRC="$1"
        shift 1
    fi

    if [ ! -d "$SRC" ] ; then
        echo "$SRC not found."
        return 1
    fi

    _gethosttype

    local OUTDIR=$(get_build_var PRODUCT_OUT)
    local TOOLS=$(get_build_var TARGET_TOOLS_PREFIX)
    local ARCHITECTURE=$(get_build_var TARGET_ARCH)
    local INTERMEDIATES=$(get_build_var TARGET_OUT_INTERMEDIATES)
    local KOUT="O=$T/$INTERMEDIATES/KERNEL"
    local CROSS="CROSS_COMPILE=$T/prebuilt/$HOSTTYPE/toolchain/arm-eabi-4.4.3/bin/arm-eabi-"
    local KARCH="ARCH=$ARCHITECTURE"

    echo "make -C $SRC $* $KARCH $CROSS $KOUT"
    (cd $T && make -C $SRC $* $KARCH $CROSS $KOUT)

    if [ -d "$T/$OUTDIR/modules" ] ; then
        rm -r $T/$OUTDIR/modules
    fi

    (mkdir -p $T/$OUTDIR/modules \
        cd $T && make modules_install -C $SRC $KARCH $CROSS $KOUT INSTALL_MOD_PATH=$T/$OUTDIR/modules \
        && mkdir -p $T/$OUTDIR/system/lib/modules && cp -f `find $T/$OUTDIR/modules -name *.ko` $T/$OUTDIR/system/lib/modules)
}

function mp()
{
    m -j$(cat /proc/cpuinfo | grep processor | wc -l) $*
}

function mmp()
{
    mm -j$(cat /proc/cpuinfo | grep processor | wc -l) $*
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
        . $T/vendor/nvidia/build/${product}/${product}.sh
    fi

    local OUTDIR=$(get_build_var PRODUCT_OUT)
    local HOSTOUT=$(get_build_var HOST_OUT)

    local FLASH_CMD="$T/$HOSTOUT/bin/nvflash"
    FLASH_CMD="$FLASH_CMD --bct flash.bct --setbct"
    if [ "${NVFLASH_ODM_DATA}" != "" ] ; then
        FLASH_CMD="$FLASH_CMD --odmdata ${NVFLASH_ODM_DATA}"
    fi
    FLASH_CMD="$FLASH_CMD --configfile flash.cfg"
    FLASH_CMD="$FLASH_CMD --create"
    # TODO: can this be removed?  See commit 63c25d2ea07972.
    [ "${NVFLASH_VERIFY}" ] && FLASH_CMD="$FLASH_CMD --verifypart -1"
    FLASH_CMD="$FLASH_CMD --bl bootloader.bin"
    FLASH_CMD="$FLASH_CMD --go"

    echo $FLASH_CMD
}

function fboot()
{
    T=$(gettop)

    if [ ! "$T" ]; then
        echo "Couldn't local the top of the tree. Try setting TOP." >&2
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
    (sudo $FASTBOOT $CMD)
}

function fflash()
{
    T=$(gettop)

    if [ ! "$T" ]; then
        echo "Couldn't local the top of the tree. Try setting TOP." >&2
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
    local FLASH_CMD=$(_flash | tail -1)
    echo $FLASH_CMD

    (cd $T/$OUTDIR && sudo $FLASH_CMD)
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

function adb-server()
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
    adb-server
    adb logcat | $T/vendor/nvidia/build/asymfilt.py
}

function stayon()
{
    adb-server
    adb shell "svc power stayon true && echo main >/sys/power/wake_lock"
}

if [ -f $HOME/lib/android/envsetup.sh ] ; then
    echo including $HOME/lib/android/envsetup.sh
    .  $HOME/lib/android/envsetup.sh
fi
