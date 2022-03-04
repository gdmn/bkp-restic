#! /usr/bin/env bash

set -e

command -v restic >/dev/null 2>&1 || { echo >&2 "Required command restic is not installed."; exit 1; }
command -v hostnamectl >/dev/null 2>&1 || { echo >&2 "Required command hostnamectl is not installed."; exit 1; }
command -v zstd >/dev/null 2>&1 || { echo >&2 "Required command zstd is not installed."; exit 1; }

show_help() {
cat << EOF
Restic backup stdin

Usage:
    $(basename $0) name - backup stdin as name.zst

Example:
    tar -c /home | $(basename $0) home.tar
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

export REMOTE_HOST="$(hostnamectl status --transient)-streams"
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
NAME="$1"

log="${HOME}/bkp-${REMOTE_HOST}-$(date +%Y%m%d_%H%M%S).log.zst"
echo "LOG: $log"
echo "NAME: $NAME"

restic version \
  2>&1 | tee >(zstd -T0 --long >> "$log")
restic init \
  2>&1 | tee >(zstd -T0 --long >> "$log") \
  || true

cat | \
ionice -c 2 -n 7 nice -n 19 \
zstd -T0 --long \
        | restic \
        --verbose \
        --no-cache \
        --tag "${NAME}" \
        --tag "stream" \
        --stdin \
        --stdin-filename="${NAME}.zst" \
        backup \
  2>&1 | tee >(zstd -T0 --long >> "$log")

exit 0
