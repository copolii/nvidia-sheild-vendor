function ksetup()
{
    T=$(gettop)
    if [ ! "$T" ]; then
        echo "Couldn't local the top of the tree. Try setting TOP." >&2
        return
    fi

    local SRC="$T/kernel"
    if [ $# -lt 1 ] ; then
        echo "Usage: ksetup <defconfig> <path>"
        return
    fi

    if [ $# -gt 1 ] ; then
        SRC="$2"
    fi

    if [ ! -d "$SRC" ] ; then
        echo "$SRC not found."
        return
    fi
    local TOOLS=$(get_build_var TARGET_TOOLS_PREFIX)
    local ARCHITECTURE=$(get_build_var TARGET_ARCH)
    local INTERMEDIATES=$(get_build_var TARGET_OUT_INTERMEDIATES)
    local KOUT="$T/$INTERMEDIATES/KERNEL"
    local CROSS="CROSS_COMPILE=$T/prebuilt/linux-x86/toolchain/arm-eabi-4.4.3/bin/arm-eabi-"
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
        return
    fi

    local SRC="$T/kernel"
    if [ -d "$1" ] ; then
        SRC="$1"
        shift 1
    fi

    if [ ! -d "$SRC" ] ; then
        echo "$SRC not found."
        return
    fi

    local TOOLS=$(get_build_var TARGET_TOOLS_PREFIX)
    local ARCHITECTURE=$(get_build_var TARGET_ARCH)
    local INTERMEDIATES=$(get_build_var TARGET_OUT_INTERMEDIATES)
    local KOUT="O=$T/$INTERMEDIATES/KERNEL"
    local CROSS="CROSS_COMPILE=$T/prebuilt/linux-x86/toolchain/arm-eabi-4.4.3/bin/arm-eabi-"
    local KARCH="ARCH=$ARCHITECTURE"

    echo "make -C $SRC $KARCH $CROSS $KOUT menuconfig"
    (cd $T && make -C $SRC $KARCH $CROSS $KOUT menuconfig)
}

function krebuild()
{
    T=$(gettop)
    if [ ! "$T" ]; then
        echo "Couldn't local the top of the tree. Try setting TOP." >&2
        return
    fi

    local SRC="$T/kernel"
    if [ -d "$1" ] ; then
        SRC="$1"
        shift 1
    fi

    if [ ! -d "$SRC" ] ; then
        echo "$SRC not found."
        return
    fi

    local OUTDIR=$(get_build_var PRODUCT_OUT)
    local TOOLS=$(get_build_var TARGET_TOOLS_PREFIX)
    local ARCHITECTURE=$(get_build_var TARGET_ARCH)
    local INTERMEDIATES=$(get_build_var TARGET_OUT_INTERMEDIATES)
    local KOUT="O=$T/$INTERMEDIATES/KERNEL"
    local CROSS="CROSS_COMPILE=$T/prebuilt/linux-x86/toolchain/arm-eabi-4.4.3/bin/arm-eabi-"
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
    local DEV=$(get_build_var TARGET_PRODUCT)
    if [ -f $T/vendor/nvidia/build/$DEV/$DEV.sh ]; then
        . $T/vendor/nvidia/build/$DEV/$DEV.sh
    fi
    local ODMDATA=""

    ODMDATA=$NVFLASH_ODM_DATA

    local OUTDIR=$(get_build_var PRODUCT_OUT)
    local HOSTOUT=$(get_build_var HOST_OUT)

    if [ -e "$T/$HOSTOUT/bin/$DEV/nvflash" ]
    then
        local FLASH_CMD="$T/$HOSTOUT/bin/$DEV/nvflash"
    else
        local FLASH_CMD="$T/$HOSTOUT/bin/nvflash"
    fi

    FLASH_CMD="$FLASH_CMD --bct flash.bct --setbct"
    if [ "$ODMDATA" != "" ] ; then
        FLASH_CMD="$FLASH_CMD --odmdata $ODMDATA"
    fi
    FLASH_CMD="$FLASH_CMD --configfile flash.cfg"

    if [ ! "$NVFLASH_VERIFY" ]
    then
      FLASH_CMD="$FLASH_CMD --create --bl bootloader.bin --go"
    else
      FLASH_CMD="$FLASH_CMD --create --verifypart -1 --bl bootloader.bin --go"
    fi

    echo $FLASH_CMD
}

function flash()
{
    T=$(gettop)
    if [ ! "$T" ]; then
        echo "Couldn't locate the top of the tree.  Try setting TOP." >&2
        return
    fi

    local OUTDIR=$(get_build_var PRODUCT_OUT)
    local FLASH_CMD=$(_flash | tail -1)
    _flash

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
        return
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
	return
    fi
    adb-server
    adb logcat | $T/vendor/nvidia/build/asymfilt.py
}
