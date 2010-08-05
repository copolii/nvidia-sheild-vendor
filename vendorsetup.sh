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
    local CROSS="CROSS_COMPILE=$T/prebuilt/linux-x86/toolchain/arm-eabi-4.4.0/bin/arm-eabi-"
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
    local CROSS="CROSS_COMPILE=$T/prebuilt/linux-x86/toolchain/arm-eabi-4.4.0/bin/arm-eabi-"
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

    local TOOLS=$(get_build_var TARGET_TOOLS_PREFIX)
    local ARCHITECTURE=$(get_build_var TARGET_ARCH)
    local INTERMEDIATES=$(get_build_var TARGET_OUT_INTERMEDIATES)
    local KOUT="O=$T/$INTERMEDIATES/KERNEL"
    local CROSS="CROSS_COMPILE=$T/prebuilt/linux-x86/toolchain/arm-eabi-4.4.0/bin/arm-eabi-"
    local KARCH="ARCH=$ARCHITECTURE"

    echo "make -C $SRC $* $KARCH $CROSS $KOUT"
    (cd $T && make -C $SRC $* $KARCH $CROSS $KOUT)
}

function nvflash()
{
    T=$(gettop)

    if [ ! "$T" ]; then
        echo "Couldn't locate the top of the tree.  Try setting TOP." >&2
        return
    fi

    local DEV=$(get_build_var TARGET_PRODUCT)
    
    local VERBOSE=
    local ODMDATA=""

    if [ "$DEV" == "harmony" ] ; then
        ODMDATA="0x300d8011"
    elif [ "$DEV" == "stingray" ] ; then
        ODMDATA="0x800c8105"
    fi

    local OUTDIR=$(get_build_var PRODUCT_OUT)
    local HOSTOUT=$(get_build_var HOST_OUT)

    local FLASH_CMD="$T/$HOSTOUT/bin/nvflash"
    FLASH_CMD="$FLASH_CMD --bct flash.bct --setbct"
    if [ "$ODMDATA" != "" ] ; then
        FLASH_CMD="$FLASH_CMD --odmdata $ODMDATA"
    fi
    FLASH_CMD="$FLASH_CMD --configfile flash.cfg"
    FLASH_CMD="$FLASH_CMD --create --bl bootloader.bin --go"

    echo $FLASH_CMD
    (cd $T/$OUTDIR && sudo $FLASH_CMD)
}

function fastboot()
{
    T=$(gettop)
    if [ ! "$T" ]; then
        echo "Couldn't local the top of the tree. Try setting TOP." >&2
        return
    fi
    local INTERMEDIATES=$(get_build_var TARGET_OUT_INTERMEDIATES)
    local OUTDIR=$(get_build_var PRODUCT_OUT)
    local HOST_OUTDIR=$(get_build_var HOST_OUT)

    local ZIMAGE=$T/$INTERMEDIATES/KERNEL/arch/arm/boot/zImage
    local RAMDISK=$T/$OUTDIR/ramdisk.img
    local FASTBOOT=$T/$HOST_OUTDIR/bin/fastboot

    local VID="0x955"
    local DEV=$(get_build_var TARGET_PRODUCT)
    if [ "$DEV" == "stingray" ] ; then
        VID="0x22b8"
    fi

    if [ ! "$FASTBOOT" ]; then
        echo "Couldn't find $FASTBOOT." >&2
        return
    fi

    if [ $# != 0 ] ; then
        CMD=$*
    else
        if [ ! "$ZIMAGE" ]; then
            echo "Couldn't find $ZIMAGE. Try setting TARGET_PRODUCT." >&2
            return
        fi
        if [ ! "$RAMDISK" ]; then
            echo "Couldn't find $RAMDISK. Try setting TARGET_PRODUCT." >&2
            return
        fi
        CMD="-i $VID boot $ZIMAGE $RAMDISK"
    fi

    echo "sudo $FASTBOOT $CMD"
    (sudo $FASTBOOT $CMD)
}
