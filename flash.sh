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
#  flash.sh [-n] [-o <odmdata>] [-s <skuid> [forcebypass]] [-m <modem>]-- [optional args]
#
# -n
#   skips using sudo on cmdline
# -o <odmdata>
#   specify ODM data to use
# -s <sku> [forcebypass]
#   specify SKU to use, with optional forcebypass flag to nvflash
# -m <modem>
#   specify modem to use ([-o <odmdata>] overrides this option)
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

        which $NVFLASH_BINARY 2> /dev/null >&2
        if [ $? != 0 ]; then
            echo "Error: make sure $NVFLASH_BINARY in \$PATH."
            exit 1
        fi

        which $NVGETDTB_BINARY 2> /dev/null >&2
        if [ $? != 0 ]; then
            echo "Error: make sure $NVGETDTB_BINARY in \$PATH."
            exit 1
        fi
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
while getopts "no:s:m:" OPTION
do
    case $OPTION in
    m) _modem=${OPTARG};
        ;;
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

# Fetch target board name. Internal builds (*_int) and generic builds (*_gen)
# share a board with the external builds.
# *_64 are the same board with a 64-bit userspace. They should flash the same.
product=$(echo ${PRODUCT_OUT%/} | sed -e 's#.*\/\(.*\)#\1#' -e 's#_\(int\|gen\|64\)$##')

###############################################################################
# TNSPEC Platform Handler
# Used by ardbeg, ...
###############################################################################

tnspec_platforms()
{
    local product=$1
    local specid=''
    local nctbin=$PRODUCT_OUT/.nvflash_nctbin

    # Debug
    TNSPEC_OUTPUT=${TNSPEC_OUTPUT:-/dev/null}

    # Tegranote boards are handled by an external tnspec.py utility
    local boards=$(tnspec spec list -g hw)
    if [[ -z $board ]] && _shell_is_interactive; then
        pr_ok_bl "Supported HW List for $product" "TNSPEC: "
        pr_warn "Choose \"auto\" to automatically detect HW" "TNSPEC: "
        tnspec spec list -v -g hw
        # Prompt user for target board info
        _choose ">> " "auto $boards" board auto simple

    else
        board=${board-auto}
    fi

    # Auto mode
    if [ $board == "auto" ]; then
        specid=$(tnspec_auto $nctbin)
        TNSPEC_UPDATE_NCT_ONLY=${TNSPEC_UPDATE_NCT_ONLY:-"no"}
        if [ -z $specid ]; then
            # if TNSPEC_UPDATE_NCT_ONLY="yes", reset the device and exit.
            if [[ "$TNSPEC_UPDATE_NCT_ONLY" == "yes" ]]; then
                pr_err "NCT update failed. Quitting..." "TNSPEC: " >&2
                recovery="--force_reset reset 100" _nvflash 2> $TNSPEC_OUTPUT >&2
                exit 1
            fi

            pr_err "Couldn't find SW Spec ID. Try choosing from the HW list." "TNSPEC: ">&2
            if _shell_is_interactive; then
                _choose ">> " "$boards" board '' simple
            else
                pr_warn "Try setting 'BOARD' env variable directly." "TNSPEC: ">&2
                exit 1
            fi
        else
            # if TNSPEC_UPDATE_NCT_ONLY="yes", reset the device and exit.
            if [[ "$TNSPEC_UPDATE_NCT_ONLY" == "yes" ]]; then
                recovery="--force_reset reset 100" _nvflash 2> $TNSPEC_OUTPUT >&2
                exit 0
            fi
            # WAR: setting 'nct' shouldn't be needed if NCT's board id is understood by
            #      Tboot and BL natively.
            tnspec nct dump nct -n $nctbin > ${nctbin}.txt
            nct="--nct \"$(_os_path ${nctbin}.txt)\""
            _su rm $nctbin
        fi
    fi

    if  [ $board != "auto" ]; then

        if ! _in_array $board $boards; then
            pr_err "HW Spec ID '$board' is not supported. Choose one from the list." "TNSPEC: "
            tnspec spec list -v -g hw
            exit 1
        fi

        specid=$(tnspec_manual $nctbin)

        if [ -z $specid ]; then
            pr_err "Couldn't find SW Spec ID. Spec needs to be updated." "TNSPEC: ">&2
            exit 1
        fi
        # override nct if SW spec doesn't use NCT.
        local skip_nct=$(tnspec spec get $specid.skip_nct -g sw)

        if [ -z $skip_nct ]; then
            pr_info "NCT created." "TNSPEC: "
            # print new nct
            tnspec nct dump -n $nctbin
            # generate nct
            tnspec nct dump nct -n $nctbin > ${nctbin}.txt
            nct="--nct \"$(_os_path ${nctbin}.txt)\""
        else
            pr_warn "$specid doesn't use NCT." "TNSPEC: "
        fi
        # remove intermediate files created by nvflash
        _su rm $nctbin
    fi

    sw_specs=$(tnspec spec list -g sw  | cut -f 1 -d ' ')
    if ! _in_array $specid $sw_specs; then
        pr_warn "$specid is not supported. Please file a bug." "TNSPEC: "
        exit 1
    fi

    # set bctfile and cfgfile based on target board
    # 'unset' forces to use default values.

    if _in_array $specid $sw_specs; then
        cfgfile=$(tnspec spec get $specid.cfg -g sw)
        [[ ${#cfgfile} == 0 ]] && unset cfgfile
        bctfile=$(tnspec spec get $specid.bct -g sw)
        [[ ${#bctfile} == 0 ]] && unset bctfile
        dtbfile=$(tnspec spec get $specid.dtb -g sw)
        [[ ${#dtbfile} == 0 ]] && unset dtbfile
        preboot=$(tnspec spec get $specid.preboot -g sw)
        [[ ${#preboot} == 0 ]] && unset preboot
        bootpack=$(tnspec spec get $specid.bootpack -g sw)
        [[ ${#bootpack} == 0 ]] && unset bootpack
        sku=$(tnspec spec get $specid.sku -g sw)
        [[ ${#sku} > 0 ]] && skuid=$sku
        odm=$(tnspec spec get $specid.odm -g sw)
        [[ ${#odm} > 0 ]] && odmdata=$odm
    fi
    pr_ok "Flashing..." "TNSPEC: "
    echo ""
}

###############################################################################
# Setup functions per target board
t132() {
    if [[ -z $board ]] && ! _shell_is_interactive; then
        board=norrin
    fi

    tnspec_platforms "Loki/TegraNote/T132"
}

ardbeg() {
    # 'shield_ers' seems to be assumed in automation testing.
    # if $board is empty and shell is not interactive, set 'shield_ers' to $board
    if [ -z $board ] && ! _shell_is_interactive; then
       board=shield_ers
    fi

    tnspec_platforms "TegraNote/Ardbeg"
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
    [[ -n $BOARD_IS_LOKI_FFD_BASE_A01 ]] && board=loki_ffd_base_a01
    [[ -n $BOARD_IS_LOKI_FFD_BASE_A03 ]] && board=loki_ffd_base_a03
    [[ -n $BOARD_IS_LOKI_NFF_B00_2GB ]] && board=loki_nff_b00_2gb
    if [[ -z $board ]] && _shell_is_interactive; then
        # Prompt user for target board info
        _choose "Which board to flash?" "e2548_a02 loki_nff_b00 loki_nff_b00_2gb thor_195 loki_ffd_prem loki_ffd_prem_a01 loki_ffd_prem_a03 loki_ffd_base loki_ffd_base_a1 loki_ffd_base_a3 foster_pro foster_pro_a01" board loki_nff_b00
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
        dtbfile=tegra124-loki-e2548-a00.dtb
    elif [[ $board == loki_nff_b00 ]]; then
        nct="--nct NCT_loki_b00.txt"
        bctfile=bct_loki_b00.cfg
        dtbfile=tegra124-loki-e2548-a00.dtb
    elif [[ $board == foster_pro ]]; then
        nct="--nct NCT_foster.txt"
        dtbfile=tegra124-foster.dtb
        bctfile=bct_loki_ffd_sku0.cfg
        odmdata=0x29c000
    elif [[ $board == foster_pro_a01 ]]; then
        nct="--nct NCT_foster_a1.txt"
        dtbfile=tegra124-foster.dtb
        bctfile=bct_loki_ffd_sku0.cfg
        odmdata=0x29c000
    elif [[ $board == loki_ffd_prem ]]; then
        nct="--nct NCT_loki_ffd_sku0.txt"
        bctfile=bct_loki_ffd_sku0.cfg
        dtbfile=tegra124-loki-e2530-a01.dtb
    elif [[ $board == loki_ffd_prem_a01 ]]; then
        nct="--nct NCT_loki_ffd_sku0_a1.txt"
        bctfile=bct_loki_ffd_sku0.cfg
        dtbfile=tegra124-loki-e2530-a01.dtb
    elif [[ $board == loki_ffd_prem_a03 ]]; then
        nct="--nct NCT_loki_ffd_sku0_a3.txt"
        bctfile=bct_loki_ffd_sku0.cfg
        dtbfile=tegra124-loki-e2530-a03.dtb
    elif [[ $board == loki_ffd_base ]]; then
        nct="--nct NCT_loki_ffd_sku100.txt"
        bctfile=bct_loki_ffd_sku100.cfg
        dtbfile=tegra124-loki-e2530-a01.dtb
    elif [[ $board == loki_ffd_base_a1 ]]; then
        nct="--nct NCT_loki_ffd_sku100_a1.txt"
        bctfile=bct_loki_ffd_sku100.cfg
        dtbfile=tegra124-loki-e2530-a01.dtb
   elif [[ $board == loki_ffd_base_a3 ]]; then
        nct="--nct NCT_loki_ffd_sku100_a3.txt"
        bctfile=bct_loki_ffd_sku100.cfg
        dtbfile=tegra124-loki-e2530-a03.dtb
    elif [[ $board == loki_nff_b00_2gb ]]; then
        nct="--nct NCT_loki_b00_sku100.txt"
        bctfile=bct_loki_b00_sku100.cfg
        dtbfile=tegra124-loki-e2548-a00.dtb
    elif [[ $board == thor_195 ]]; then
        nct="--nct NCT_thor1_95.txt"
        bctfile=bct_thor1_95.cfg
        dtbfile=tegra124-loki-thor195-e2549-a00.dtb
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
    local quiet=${5-''}                # $5: Hide choices from prompt
    local selected=''
    while [[ -z $selected ]] ; do
        if [[ -n $quiet ]]; then
            read -e -p "$query" -i "$default" input
        else
            read -e -p "$query [${choices[*]}] " -i "$default" input
        fi
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

# Update odmdata regarding required modem:
# select through bits [7:3] of odmdata
# e.g max value is 0x1F
_mdm_odm() {
    if [[ $_modem ]]; then
        if [[ $_modem -lt 0x1F ]]; then
            # 1st: disable modem
            disable_mdm=$(( ~(0x1F << 3) ))
            odmdata=$(( $odmdata & $disable_mdm ))
            # 2nd: select required modem
            odmdata=`printf "0x%x" $(( $odmdata | $(( $_modem << 3 )) ))`
        else
            echo "Warning: Unknown modem reference [${_modem}]. Unchanged odmdata."
        fi
    fi
}

# Automatically detect HW type and generate NCT if necessary
tnspec_auto() {
    local nctbin=$1
    pr_warn "Detecting board type...." "TNSPEC: " >&2
    pr_info "- if this takes more than 10 seconds, put the device into recovery mode" "TNSPEC: " >&2
    pr_info "  and choose from the HW list instead of \"auto\"." "TNSPEC: " >&2
    # Check if NCT partition exists first
    _download_NCT $nctbin 2> $TNSPEC_OUTPUT >&2
    if [ $? == 0 ]; then
        # Dump NCT partion
        pr_info "NCT Found. Checking SPEC..."  "TNSPEC: ">&2

        local hwid=$(tnspec nct dump spec -n $nctbin | _tnspec spec get id -g hw)
        if [ -z "$hwid" ]; then
            pr_err "NCT's spec partition or 'id' is missing in NCT." "TNSPEC: " >&2
            pr_warn "Dumping NCT..." "TNSPEC: " >&2
            tnspec nct dump -n $nctbin >&2
            return 1
        fi
        pr_info "SPEC found. Retrieving SW specid.." "TNSPEC: " >&2
        if [ ! -z "$hwid" ]; then
            local config=$(tnspec nct dump spec -n $nctbin | _tnspec spec get config -g hw)
            config=${config:-default}
            local spec_id=$hwid.$config

            pr_ok "SW Spec ID: $spec_id" "TNSPEC: " >&2
            pr_info "Check if NCT needs to be updated.." "TNSPEC: " >&2

            # Update NCT from SW specs. (SW shouldn't touch HW spec)
            tnspec nct update $spec_id -o ${nctbin}_update -n $nctbin -g sw
            if [ $? != 0 ]; then
                pr_err "tnspec tool had an error." "TNSPEC: " >&2
                return 1
            fi

            _su diff -b ${nctbin}_update $nctbin 2> $TNSPEC_OUTPUT >&2
            if [ $? != 0 ]; then
                pr_warn "NCT needs to be updated. Differences are:" "TNSPEC: " >&2
                tnspec nct dump -n $nctbin > ${nctbin}_diff_old
                tnspec nct dump -n ${nctbin}_update > ${nctbin}_diff_new

                # print difference between old and new version
                diff -u ${nctbin}_diff_old ${nctbin}_diff_new >&2

                rm  ${nctbin}_diff_old ${nctbin}_diff_new

                pr_info "Updating NCT" "TNSPEC: " >&2

                _nvflash --download NCT $(_os_path ${nctbin}_update ) 2> $TNSPEC_OUTPUT >&2
                pr_ok "Done updating NCT" "TNSPEC: ">&2
            else
                pr_warn "Nothing to update for NCT. Printing NCT." "TNSPEC: ">&2
                tnspec nct dump -n $nctbin >&2
            fi
            _su mv ${nctbin}_update $nctbin
            echo $spec_id
            return 0
        fi
    fi
    return 1
}

tnspec_manual() {
    local nctbin=$1
    local hwid=$(tnspec spec get $board.id -g hw)
    if [ -z $hwid ]; then
        pr_err "Couldn't find 'id' field from HW Spec '$board'." "TNSPEC: " >&2
        pr_warn "Dumping HW Spec '$board'." "TNSPEC: " >&2
        tnspec spec get $board -g hw >&2
        return 1
    fi
    local config=$(tnspec spec get $board.config -g hw)
    config=${config:-default}
    local spec_id=$hwid.$config

    _su rm $nctbin 2> $TNSPEC_OUTPUT >&2
    tnspec nct new $board -o $nctbin

    echo $spec_id
}

# Pretty prints ($2 - optional header)
pr_info() {
    if  _shell_is_interactive; then
        echo -e "\033[95m$2\033[0m$1"
    else
        echo $2$1
    fi
}
pr_ok() {
    if _shell_is_interactive; then
        echo -e "\033[95m$2\033[0m\033[92m$1\033[0m"
    else
        echo $2$1
    fi
}
pr_ok_bl() {
    if  _shell_is_interactive; then
        echo -e "\033[95m$2\033[0m\033[94m$1\033[0m"
    else
        echo $2$1
    fi
}
pr_warn() {
    if  _shell_is_interactive; then
        echo -e "\033[95m$2\033[0m\033[93m$1\033[0m"
    else
        echo $2$1
    fi
}
pr_err() {
    if _shell_is_interactive; then
        echo -e "\033[95m$2\033[0m\033[91m$1\033[0m"
    else
        echo $2$1
    fi
}
# sudo nvflash
_nvflash() {
    if [[ -n $_nosudo ]]; then
        flash_cmd="$NVFLASH_BINARY"
    else
        flash_cmd="sudo $NVFLASH_BINARY"
    fi

    recovery=${recovery:---force_reset recovery 300}
    # always wait for the device to be in recovery mode
    echo "$flash_cmd --wait  $@ --bl $(_os_path $PRODUCT_OUT/bootloader.bin) $recovery" 2> $TNSPEC_OUTPUT >&2
    $flash_cmd --wait  $@ --bl $(_os_path $PRODUCT_OUT/bootloader.bin) $recovery
}
# su
_su() {
    if [[ -n $_nosudo ]]; then
        $@
    else
        sudo $@
    fi
}

# get CID
_get_cid()
{
    local cid_output=$PRODUCT_OUT/.nvflash_cid
    local cid=''
    _nvflash > $cid_output
    if [ $? != 0 ]; then
        cat $cid_output
        pr_err "nvflash failed." >&2
        return 1
    fi
    cid=$(cat $cid_output | grep "BR_CID:" | cut -f 2 -d ' ')
    if [ -z $cid ]; then
        cid=$(cat $cid_output | grep "uid from" | cut -f 6 -d ' ')
    fi
    rm $cid_output
    echo $cid
}

# convert unix path to windows path
_os_path()
{
    if [ $OSTYPE == cygwin ]; then
        echo $(cygpath -w $1)
    else
        echo $1
    fi
}

# download NCT
_download_NCT() {
    local x

    local partinfo=$PRODUCT_OUT/.nvflash_partinfo
    local nctbin=$1

    # generated directly by nvflash
    _su rm $partinfo $nctbin 2> $TNSPEC_OUTPUT >&2

    # download partition table
    _nvflash --getpartitiontable $(_os_path $partinfo) 2> $TNSPEC_OUTPUT >&2

    if [ $? != 0 ]; then
        pr_err "Failed to download partition table" "TNSPEC: " >&2
        return 1
    fi
    # cid for future use

    x=$(grep NCT $partinfo)
    _su rm $partinfo

    if [ -z "$x" ]; then
       pr_err "No NCT partition found" "TNSPEC: " >&2
       return 1
    fi

    _nvflash --read NCT $(_os_path $nctbin) 2> $TNSPEC_OUTPUT >&2
    if [ $? != 0 ];then
        pr_err "Failed to download NCT" "TNSPEC: " >&2
        return 1
    fi
    # do not delete $nctbin
    return 0
}

# tnspec w/o spec
_tnspec() {
    local tnspec_bin=$PRODUCT_OUT/tnspec.py
    # return nothing if tnspec tool or spec file is missing
    if [ ! -x $tnspec_bin ]; then
        pr_err "Error: tnspec.py doesn't exist or is not executable." "TNSPEC: " >&2
        return
    fi
    $tnspec_bin $@
}

# tnspec wrapper
tnspec() {
    local tnspec_spec=$PRODUCT_OUT/tnspec.json
    local tnspec_spec_public=$PRODUCT_OUT/tnspec-public.json

    if [ ! -f $tnspec_spec ]; then
        if [ ! -f $tnspec_spec_public ]; then
            pr_err "Error: tnspec.json doesn't exist." "TNSPEC: " >&2
            return
        fi
        tnspec_spec=$tnspec_spec_public
    fi

    _tnspec $@ -s $tnspec_spec
}

# Set all needed parameters
_set_cmdline() {
    # Set modem in odmdata if required
    _mdm_odm

    # Set ODM data, BCT and CFG files (with fallback defaults)
    odmdata=${_odmdata-${odmdata-"0x98000"}}
    bctfile=${bctfile-"bct.cfg"}
    cfgfile=${cfgfile-"flash.cfg"}

    # Set NCT option, defaults to empty
    nct=${nct-""}

    # Set SKU ID, MTS settings. default to empty
    skuid=${_skuid-${skuid-""}}
    [[ -n $skuid ]] && skuid="-s $skuid"
    preboot=${preboot-""}
    [[ -n $preboot ]] && preboot="--preboot $preboot"
    bootpack=${bootpack-""}
    [[ -n $bootpack ]] && bootpack="--bootpack $bootpack"

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
        fi
        dtbfile=$_dtbfile
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
