#!/bin/bash

if [ a$GERRIT_USER == a ]; then
  export GERRIT_USER=$USER
fi

#directory, patchname
function apply_patch {
    echo === Changing to $TOP/$1 to apply patch
    pushd $TOP/$1
    echo === git am $TOP/vendor/nvidia/build/$2
    git am $TOP/vendor/nvidia/build/$2
    if [ $? != 0 ]; then
        echo === error: Applying patch failed!
        echo === Aborting!
        echo === Restoring original directory
        popd
        exit 1
    fi
    echo === Restoring original directory
    popd
}

if [ a$TOP == a ]; then
    echo \$TOP is not set. Please set \$TOP before running this script
    exit 1
else
    
    # Fix issue with DEBUG_OUT_DIR not properly selected
    cherry_pick build f7dfb3689edcaf5f819fa5e691ce13abf858bca8
    # pdk: Support AIDL files in java builds
    cherry_pick build 3484c5a32d95ed1f8d4a7746e5f2f6559714630f
    # enable NV_ANDROID_FRAMEWORKS_ENHANCEMENT flag
    cherry-pick build 8e5c9b409eac0a2d56ea519ca35f749d590cd0a4
    
    # Enable support for bcm modules
    cherry_pick hardware/libhardware_legacy e7678a06bc413e93f9cf612b9f38c7db5020e51b

    # tinyalsa: return card number from its name substring
    cherry_pick external/tinyalsa c3828fdc2ae1051bd2ca2c8e932f9ce6d61b0c19

    # Enable use of ro.sf.lcd_density prop by system user
    cherry_pick system/core 59e8f07a05b1f03a4d4802870420fe2fa0f225c2

    # apply frameworks/native patches for powerservice.
    apply_patch frameworks/native patches/frameworks/native/*

    # appply hardware/libhardware patches for powerservice.
    apply_patch hardware/libhardware patches/hardware/libhardware/*
fi

