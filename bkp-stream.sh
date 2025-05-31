#! /usr/bin/env bash

set -e

command -v restic >/dev/null 2>&1 || { echo >&2 "Required command restic is not installed."; exit 1; }
command -v zstd >/dev/null 2>&1 || { echo >&2 "Required command zstd is not installed."; exit 1; }

show_help() {
cat << EOF
Restic backup stdin

Usage:
    $(basename $0) name - backup stdin as "name"

Example:
    tar -c /home | $(basename $0) home.tar
    date | $(basename $0) date.txt

To clean:
    filter="--tag stream"; restic forget --keep-last 1 \$filter; restic snapshots \$filter | grep -E '^[0-9a-f]{8}.*stream.*' | sed -E 's/(^[0-9a-f]{8}).*/\\1/' | while read id; do restic forget \$id; done; restic prune --max-unused 0
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

export REMOTE_HOST="$(hostnamectl status --transient 2>/dev/null || hostname)-streams"
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

if command -v ionice >/dev/null 2>&1; then
    lowprio="ionice -c 2 -n 7 nice -n 19"
else
    lowprio="nice -n 19"
fi

cat | \
$lowprio \
        restic \
        --verbose \
        --no-cache \
        --no-scan \
        --tag="${NAME}" \
        --tag="stream" \
        --stdin \
        --stdin-filename="${NAME}" \
        backup \
  2>&1 | tee >(zstd -T0 --long >> "$log")

exit 0

