#!/bin/bash

if [ a$GERRIT_USER == a ]; then
  export GERRIT_USER=$USER
fi

if [ a$TOP == a ]; then
    echo \$TOP is not set. Please set \$TOP before running this script
    exit 1
else
    echo === Changing to $TOP/system/core to apply patch
    pushd $TOP/system/core
    echo === git am $TOP/vendor/nvidia/build/0001-TEMPORARY-Re-add-LOG-variants.patch
    git am $TOP/vendor/nvidia/build/0001-TEMPORARY-Re-add-LOG-variants.patch
    if [ $? != 0 ]; then
        echo === error: Applying patch failed!
        echo === Aborting!
        echo === Restoring original directory
        popd
        exit 1
    fi
    echo === Restoring original directory
    popd
fi

