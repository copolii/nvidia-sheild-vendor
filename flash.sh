#!/bin/bash
#
# Copyright (c) 2013-2014, NVIDIA CORPORATION.  All rights reserved.
#
# NVFlash wrapper script for flashing Android from either build environment
# or from a BuildBrain output.tgz package. This script is not intended to be
# called directly, but from vendorsetup.sh 'flash' function or BuildBrain
# package flashing script, which set required environment variables:
#
#  PRODUCT_OUT      - target build output files
#  NVFLASH_BINARY   - path to nvflash executable
#  NVGETDTB_BINARY  - path to nvgetdtb executable
#
# Usage:
#  flash.sh [-n] [-o <odmdata>] [-s <skuid> [forcebypass]] -- [optional args]
#
# -n
#   skips using sudo on cmdline
# -o <odbdata>
#   specify ODM data to use
# -s <sku> [forcebypass]
#   specify SKU to use, with optional forcebypass flag to nvflash
#
# optional arguments after '--' are added as-is to nvflash cmdline before
#  '--go' argument, which must be last.

# Option precedence is as follows:
#
# 1. Command-line options override all others.
#  (assuming there are alternative configurations to choose from:)
# 2. Shell environment variables (BOARD, for predefining target board)
# 3. If shell is interactive, prompt for input from user
# 4. If shell is non-interactive, use default values

######################################################
# Shell is non-interactive in mobile sanity testing! #
######################################################

# Mandatory arguments, passed from calling scripts.
if [[ ! -d ${PRODUCT_OUT} ]]; then
    echo "error: \${PRODUCT_OUT} not set or not a directory"
    exit 1
fi

# Detect OS, then set/verify nvflash binary accordingly.
case $OSTYPE in
    cygwin)
        NVFLASH_BINARY="nvflash.exe"
        NVGETDTB_BINARY="nvgetdtb.exe"
        _nosudo=1
        ;;
    linux*)
        if [[ ! -x ${NVFLASH_BINARY} ]]; then
            echo "error: \${NVFLASH_BINARY} not set or not an executable file"
            exit 1
        fi
        if [[ ! -x ${NVGETDTB_BINARY} ]]; then
            echo "error: \${NVGETDTB_BINARY} not set or not an executable file"
            exit 1
        fi
        ;;
    *)
        echo "error: unsupported OS type $OSTYPE detected"
        exit 1
        ;;
esac

# Optional arguments
while getopts "no:s:" OPTION
do
    case $OPTION in
    n) _nosudo=1;
        ;;
    o) _odmdata=${OPTARG};
        ;;
    s) _skuid=${OPTARG};
        if [ "$3" == "forcebypass" ]; then
            _skuid="$_skuid $3"
            shift
        fi
        ;;
    esac
done

# Optional command-line arguments, added to nvflash cmdline as-is:
# flash -b my_flash.bct -- <args to nvflash>
shift $(($OPTIND - 1))
_args=$@

# If BOARD is set, use it as predefined board name
[[ -n $BOARD ]] && board="$BOARD"

# Fetch target board name.  Internal builds (*_int) share a board
# with the external builds.
# *_64 are the same board with a 64-bit userspace. They should flash the same.
product=$(echo ${PRODUCT_OUT%/} | sed -e 's#.*\/\(.*\)#\1#' -e 's#_int$##' -e 's#_64$##')

##################################
# tnspec
tnspec() {
    # return nothing if tnspec tool or spec file is missing
    if [[ ! -x $TNSPEC_BIN ]]; then
        echo "Error: tnspec.py (\"$TNSPEC_BIN\") doesn't exist or is not executable." >&2
        return
    fi
    if [[ ! -f $TNSPEC_SPEC ]]; then
        echo "Error: tnspec.json (\"$TNSPEC_SPEC\") doesn't exist." >&2
        return
    fi

    $TNSPEC_BIN $* -s $TNSPEC_SPEC
}

# Setup functions per target board
t132() {
    odmdata=0x98000
    bctfile=bct_pm374_792.cfg
    preboot="--preboot mts_preboot_si"
    bootpack="--bootpack mts_si"

    if [[ -z $board ]] && _shell_is_interactive; then
        # prompt user for target board info
        _choose "which board to flash?" "norrin norrin_prod laguna" board norrin
    else
        board=${board-norrin}
    fi

    # set bctfile and cfgfile based on target board
    if [[ $board == norrin ]]; then
        cfgfile=norrin_flash.cfg
        dtbfile=tegra132-norrin.dtb
    elif [[ $board == norrin_prod ]]; then
        cfgfile=norrin_prod_flash.cfg
        dtbfile=tegra132-norrin.dtb
	preboot="--preboot mts_preboot_prod"
	bootpack="--bootpack mts_prod"
    elif [[ $board == laguna ]]; then
        bctfile=bct_pm359_102.cfg
        cfgfile=laguna_flash.cfg
        dtbfile=tegra132-laguna.dtb
    fi
}

ardbeg() {
    odmdata=0x98000
    skuid=auto

    # Tegranote boards are handled by an external tnspec.py utility
    tn_boards=$(tnspec list)

    if [[ -z $board ]] && _shell_is_interactive; then
        # Prompt user for target board info
        _choose "which board to flash?" "tn8 $tn_boards shield_ers laguna" board shield_ers
    else
        board=${board-shield_ers}
    fi

    # set bctfile and cfgfile based on target board
    if _in_array $board $tn_boards; then
        # Print information for selected board
        tnspec info $board

        cfgfile=$(tnspec cfg $board)
        [[ ${#cfgfile} == 0 ]] && unset cfgfile
        bctfile=$(tnspec bct $board)
        [[ ${#bctfile} == 0 ]] && unset bctfile
        dtbfile=$(tnspec dtb $board)
        [[ ${#dtbfile} == 0 ]] && unset dtbfile
        sku=$(tnspec sku $board)
        [[ ${#sku} > 0 ]] && skuid=$sku
        odm=$(tnspec odm $board)
        [[ ${#odm} > 0 ]] && odmdata=$odm

        # generate NCT
        tnspec nct $board > $PRODUCT_OUT/nct_$board.txt
        if [ $? -eq 0 ]; then
            nct="--nct nct_$board.txt"
        else
            echo "Failed to generate NCT file for $board"
        fi
    # Mobile sanity uses board name "tn8"
    elif [[ $board == tn8 ]]; then
        dtbfile="tegra124-tn8.dtb"
        cfgfile="tn8_flash.cfg"
        nct="--nct nct_tn8.txt"
    elif [[ $board == shield_ers ]]; then
        dtbfile="tegra124-ardbeg-a03-00.dtb"
    elif [[ $board == laguna ]]; then
        bctfile=flash_pm358_792.cfg
        cfgfile=laguna_flash.cfg
    fi
}

loki() {
    odmdata=0x69c000
    skuid=0x7

    # Set internal board identifier
    [[ -n $BOARD_IS_E2548 ]] && board=e2548_a02
    [[ -n $BOARD_IS_THOR_195 ]] && board=thor_195
    [[ -n $BOARD_IS_FOSTER_PRO ]] && board=foster_pro
    [[ -n $BOARD_IS_FOSTER_PRO_A01 ]] && board=foster_pro_a01
    [[ -n $BOARD_IS_LOKI_NFF_B00 ]] && board=loki_nff_b00
    [[ -n $BOARD_IS_LOKI_FFD_PREM ]] && board=loki_ffd_prem
    [[ -n $BOARD_IS_LOKI_FFD_PREM_A01 ]] && board=loki_ffd_prem_a01
    [[ -n $BOARD_IS_LOKI_FFD_PREM_A03 ]] && board=loki_ffd_prem_a03
    [[ -n $BOARD_IS_LOKI_FFD_BASE ]] && board=loki_ffd_base
    [[ -n $BOARD_IS_LOKI_NFF_B00_2GB ]] && board=loki_nff_b00_2gb
    if [[ -z $board ]] && _shell_is_interactive; then
        # Prompt user for target board info
        _choose "Which board to flash?" "e2548_a02 loki_nff_b00 loki_nff_b00_2gb thor_195 loki_ffd_prem loki_ffd_prem_a01 loki_ffd_prem_a03 loki_ffd_base loki_ffd_base_a1_2gb foster_pro foster_pro_a01" board loki_nff_b00
    else
        board=${board-loki_nff_b00}
    fi

    # Set bctfile and cfgfile based on target board.
    # TEMP: always flash NCT for the boards until
    # final flashing procedure is fully implemented
    cfgfile=flash.cfg
    dtbfile=tegra124-loki.dtb
    if [[ $board == e2548_a02 ]]; then
        nct="--nct NCT_loki.txt"
        bctfile=bct.cfg
    elif [[ $board == loki_nff_b00 ]]; then
        nct="--nct NCT_loki_b00.txt"
        bctfile=bct_loki_b00.cfg
    elif [[ $board == foster_pro ]]; then
        nct="--nct NCT_foster.txt"
        dtbfile=tegra124-foster.dtb
        bctfile=bct_loki_ffd_sku0.cfg
        odmdata=0x29c000
    elif [[ $board == foster_pro_a01 ]]; then
        nct="--nct NCT_foster_a1.txt"
        l_dtbfile=tegra124-foster.dtb
        bctfile=bct_loki_ffd_sku0.cfg
        odmdata=0x29c000
    elif [[ $board == loki_ffd_prem ]]; then
        nct="--nct NCT_loki_ffd_sku0.txt"
        bctfile=bct_loki_ffd_sku0.cfg
    elif [[ $board == loki_ffd_prem_a01 ]]; then
        nct="--nct NCT_loki_ffd_sku0_a1.txt"
        bctfile=bct_loki_ffd_sku0.cfg
    elif [[ $board == loki_ffd_prem_a03 ]]; then
        nct="--nct NCT_loki_ffd_sku0_a3.txt"
        bctfile=bct_loki_ffd_sku0.cfg
    elif [[ $board == loki_ffd_base ]]; then
        nct="--nct NCT_loki_ffd_sku100.txt"
        bctfile=bct_loki_ffd_sku100.cfg
    elif [[ $board == loki_ffd_base_a1_2gb ]]; then
        nct="--nct NCT_loki_ffd_sku100_a1.txt"
        bctfile=bct_loki_ffd_sku100.cfg
    elif [[ $board == loki_nff_b00_2gb ]]; then
        nct="--nct NCT_loki_b00_sku100.txt"
        bctfile=bct_loki_b00_sku100.cfg
    elif [[ $board == thor_195 ]]; then
        nct="--nct NCT_thor1_95.txt"
        dtbfile=tegra124-thor195.dtb
        bctfile=bct_thor1_95.cfg
    fi
}

###################
# Utility functions

# Test if we have a connected output terminal
_shell_is_interactive() { tty -s ; return $? ; }

# Test if string ($1) is found in array ($2)
_in_array() {
    local hay needle=$1 ; shift
    for hay; do [[ $hay == $needle ]] && return 0 ; done
    return 1
}

# Display prompt and loop until valid input is given
_choose() {
    _shell_is_interactive || { "error: _choose needs an interactive shell" ; exit 2 ; }
    local query="$1"                   # $1: Prompt text
    local -a choices=($2)              # $2: Valid input values
    local input=$(eval "echo \${$3}")  # $3: Variable name to store result in
    local default=$4                   # $4: Default choice
    local selected=''
    while [[ -z $selected ]] ; do
        read -e -p "$query [${choices[*]}] " -i "$default" input
        if ! _in_array "$input" "${choices[@]}"; then
            echo "error: $input is not a valid choice. Valid choices are:"
            printf ' %s\n' ${choices[@]}
        else
            selected=$input
        fi
    done
    eval "$3=$selected"
    # If predefined input is invalid, return error
    _in_array "$selected" "${choices[@]}"
}

# Set all needed parameters
_set_cmdline() {
    # Set ODM data, BCT and CFG files (with fallback defaults)
    odmdata=${_odmdata-${odmdata-"0x98000"}}
    bctfile=${bctfile-"bct.cfg"}
    cfgfile=${cfgfile-"flash.cfg"}

    # Set NCT option, defaults to empty
    nct=${nct-""}
    preboot=${preboot-""}
    bootpack=${bootpack-""}

    # Set SKU ID, default to empty
    skuid=${_skuid-${skuid-""}}
    [[ -n $skuid ]] && skuid="-s $skuid"

    # Update DTB filename if not previously set. Note that nvgetdtb is never executed
    # in mobile sanity testing (Bug 1439258)
    if [[ -z $dtbfile ]] && _shell_is_interactive; then
        local _dtbfile=$(sudo $NVGETDTB_BINARY)
        if [ $? -eq 0 ]; then
            echo "INFO: nvgetdtb: Using $dtbfile for $product product"
        else
            echo "INFO: nvgetdtb couldn't retrieve the dtbfile for $product product"
            _dtbfile=$(grep dtb ${PRODUCT_OUT}/$cfgfile | cut -d "=" -f 2)
            echo "INFO: Using the default product dtb file $_dtbfile"
            dtbfile=$_dtbfile
        fi
    else
        # Default used in automated sanity testing is "unknown"
        dtbfile=${dtbfile-"unknown"}
    fi

    # Parse nvflash commandline
    cmdline=(
        --bct $bctfile
        --setbct
        --odmdata $odmdata
        --configfile $cfgfile
        --dtbfile $dtbfile
        --create
        --bl bootloader.bin
        --wait
        $skuid
        $nct
        $preboot
        $bootpack
        --go
    )
}

###########
# Main code

# Run product function to set needed parameters
eval $product
_set_cmdline

# If -n is set, don't use sudo when calling nvflash
if [[ -n $_nosudo ]]; then
    cmdline=($NVFLASH_BINARY ${cmdline[@]})
else
    cmdline=(sudo $NVFLASH_BINARY ${cmdline[@]})
fi

# Add optional command-line arguments
if [[ $_args ]]; then
    # This assumes '--go' is last in cmdline
    unset cmdline[${#cmdline[@]}-1]
    cmdline=(${cmdline[@]} ${_args[@]} --go)
fi

echo "INFO: PRODUCT_OUT = $PRODUCT_OUT"
echo "INFO: CMDLINE = ${cmdline[@]}"

# Execute command
(cd $PRODUCT_OUT && eval ${cmdline[@]})
exit $?
