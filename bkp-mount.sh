#! /usr/bin/env bash

set -e

command -v restic >/dev/null 2>&1 || { echo >&2 "Required command restic is not installed."; exit 1; }

CONFIGURATION_DIR="$HOME/.config/bkp-restic"

show_help() {
cat << EOF
Mount restic backup

Usage:
    $(basename $0) --help - help and usage
    $(basename $0) my-pc - mount 'my-pc' backup at temporary directory
    $(basename $0) my-pc ./my-pc-backup - mount 'my-pc' backup at './my-pc-backup' directory

For more information, see https://github.com/gdmn/bkp-restic/blob/main/README.md
EOF
}

if [ $# -lt 1 ]; then
    show_help
    exit 1
fi
if [[ "$1" == "--help" ]]; then
    show_help
    exit 0
fi

REMOTE_HOST="$1"
MOUNT_DIR="${2:-$( mktemp -d )}"
RESTIC_EXE="restic"
SUDO_RESTIC_EXE="sudo restic"

if [ ! -d "$MOUNT_DIR" ] ; then
    echo "Directory does not exist: $MOUNT_DIR"
fi

SCRIPT_DIR="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
if command -v "bkp-env.sh" >/dev/null 2>&1 ; then
    CMD_BKP_ENV="bkp-env.sh"
elif command -v "${SCRIPT_DIR}/bkp-env.sh" >/dev/null 2>&1 ; then
    CMD_BKP_ENV="${SCRIPT_DIR}/bkp-env.sh"
fi
if [ -z ${CMD_BKP_ENV+x} ]; then
    echo "Can not find bkp-env.sh"
    exit 3
fi
. $CMD_BKP_ENV --no-auto
bkp_load_env "$REMOTE_HOST"
bkp_verify_env

$RESTIC_EXE version

$SUDO_RESTIC_EXE mount --allow-other=true "$MOUNT_DIR"

