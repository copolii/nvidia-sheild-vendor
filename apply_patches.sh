#!/bin/bash

if [ a$GERRIT_USER == a ]; then
  export GERRIT_USER=$USER
fi

export GENERATE=0

if [ $1 == generate ]; then
    export GENERATE=1
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

#directory, commitid
function cherry_pick {
    echo === Changing to $TOP/$1 to cherry pick
    pushd $TOP/$1
    if [ $GENERATE == 1 ]; then
        echo === git format-patch $2
        git fetch ssh://git-master.nvidia.com:12001/android/platform/$1 rel-17-partner
        if [ $? != 0 ]; then
            echo === error: Downloading patch failed!
            echo === Aborting!
            echo === Restoring original directory
            popd
            exit 1
        fi
        mkdir -p $TOP/vendor/nvidia/build/patches/$1/$2/
        git format-patch -N -1 -o $TOP/vendor/nvidia/build/patches/$1/$2/ $2
    else
        echo === git am $TOP/vendor/nvidia/build/patches/$1/$2
        git am $TOP/vendor/nvidia/build/patches/$1/$2/*.patch
        if [ $? != 0 ]; then
            echo === error: Applying patch failed!
            echo === Aborting!
            echo === Restoring original directory
            popd
            exit 1
        fi
    fi
    echo === Restoring original directory
    popd
}

if [ a$TOP == a ]; then
    echo \$TOP is not set. Please set \$TOP before running this script
    exit 1
else
    # Frameworks: Native: Add PowerService support
    cherry_pick frameworks/native 88509af1e958ab619b54c84f8a793a89af9c2ceb

    # Fix issue with DEBUG_OUT_DIR not properly selected
    cherry_pick build f7dfb3689edcaf5f819fa5e691ce13abf858bca8
    # pdk: Support AIDL files in java builds
    cherry_pick build 3484c5a32d95ed1f8d4a7746e5f2f6559714630f

    # power: allow easy access to number of powerhal hints
    cherry_pick hardware/libhardware 0d1c4d505dd8037aeea2191fce0ff5a09f4a87f9
    # power: Add POWER_HINT_APP_PROFILES to powerhal
    cherry_pick hardware/libhardware f98edc687f6f6ff430c6da81ac8772d8aa6f60f9
    # power: Add POWER_HINT_APP_LAUNCH to power hints
    cherry_pick hardware/libhardware 400a976aba7dccbd07b25057029b759cf6430a65

    # Enable support for bcm modules
    cherry_pick hardware/libhardware_legacy e7678a06bc413e93f9cf612b9f38c7db5020e51b

    # tinyalsa: return card number from its name substring
    cherry_pick external/tinyalsa c3828fdc2ae1051bd2ca2c8e932f9ce6d61b0c19
fi

