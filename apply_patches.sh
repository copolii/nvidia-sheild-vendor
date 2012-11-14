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
    apply_patch build 0001-Fix-issue-with-DEBUG_OUT_DIR-not-properly-selected.patch
    apply_patch build 0002-build-Fix-Argument-list-too-long-error.patch
    apply_patch build 0003-pdk-Support-AIDL-files-in-java-builds.patch
    apply_patch frameworks/native 0001-egl-Return-values-from-eglDestroyImageKHR.patch
    apply_patch frameworks/native 0002-frameworks-native-add-extra-dalvik-heap-configs.patch
    apply_patch hardware/libhardware_legacy 0001-Enable-support-for-bcm-modules.patch
    apply_patch system/core 0001-TEMPORARY-Re-add-LOG-variants.patch
    apply_patch system/core 0002-Enable-use-of-modem.-property-by-radio-user.patch
    apply_patch system/core 0003-Enable-use-of-ro.sf.lcd_density-prop-by-system-user.patch
    apply_patch system/core 0001-audio-add-ulp-audio-format-query.patch
    #apply_patch frameworks/av 0001-AudioFlinger-Support-ULP-audio-on-Android-JB.patch
    apply_patch hardware/libhardware_legacy 0001-audio-policy-Add-WFD-device-in-Audio-Policy-Manager-.patch
    apply_patch hardware/libhardware 0001-usbaudio-Get-card-number-from-substring.patch
    apply_patch external/tinyalsa 0001-external-tinyalsa-Enable-tinyalsa-apps-in-JB-build.patch
fi

