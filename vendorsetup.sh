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

    echo "Building boot.img"

    local HOST_OUTDIR=$(get_build_var HOST_OUT)
    local ZIMAGE=$T/$INTERMEDIATES/KERNEL/arch/arm/boot/zImage
    local RAMDISK=$T/$OUTDIR/ramdisk.img
    local MKBOOTIMG=$T/$HOST_OUTDIR/bin/mkbootimg

    if [ ! "$ZIMAGE" ]; then
        echo "Couldn't find $ZIMAGE. Your KERNEL is not build." >&2
        return
    fi
    if [ ! "$RAMDISK" ]; then
        echo "Couldn't find $RAMDISK. Your ANDROID system is not build." >&2
        return
    fi
    if [ ! "$MKBOOTIMG" ]; then
        echo "Couldn't find $MKBOOTIMG. Your ANDROID system is not build." >&2
        return
    fi

    CMD="--kernel $ZIMAGE --ramdisk $RAMDISK -o $T/$OUTDIR/boot.img"

    echo "$MKBOOTIMG $CMD"
    ($MKBOOTIMG $CMD)

    echo "boot.img is ready"
}

function nvflash()
{
    T=$(gettop)

    if [ ! "$T" ]; then
        echo "Couldn't locate the top of the tree.  Try setting TOP." >&2
        return
    fi

    local DEV=$(get_build_var TARGET_PRODUCT)
    if [ -f $T/vendor/nvidia/build/$DEV/$DEV.sh ]; then
	. $T/vendor/nvidia/build/$DEV/$DEV.sh
    fi
    local VERBOSE=
    local ODMDATA=""

    ODMDATA=$NVFLASH_ODM_DATA

    local OUTDIR=$(get_build_var PRODUCT_OUT)
    local HOSTOUT=$(get_build_var HOST_OUT)

    local FLASH_CMD="$T/$HOSTOUT/bin/$DEV/nvflash"
    FLASH_CMD="$FLASH_CMD --bct flash.bct --setbct"
    if [ "$ODMDATA" != "" ] ; then
        FLASH_CMD="$FLASH_CMD --odmdata $ODMDATA"
    fi
    FLASH_CMD="$FLASH_CMD --configfile flash.cfg"
    FLASH_CMD="$FLASH_CMD --create --bl bootloader.bin --go"

    echo $FLASH_CMD
    (cd $T/$OUTDIR && sudo $FLASH_CMD)
}

function fboot()
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
    local DEV=$(get_build_var TARGET_PRODUCT)
    if [ -f $T/vendor/nvidia/build/$DEV/$DEV.sh ]; then
       . $T/vendor/nvidia/build/$DEV/$DEV.sh
    fi
    local VID=""
    VID=$FASTBOOT_VID

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

