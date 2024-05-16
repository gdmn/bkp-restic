#! /usr/bin/env bash

set -e

command -v restic >/dev/null 2>&1 || { echo >&2 "Required command restic is not installed."; exit 1; }
command -v zstd >/dev/null 2>&1 || { echo >&2 "Required command zstd is not installed."; exit 1; }

show_usage() {
cat << EOF
Restic backup openwrt router using /cgi-bin/cgi-backup endpoint.

Usage:
    $(basename $0) host - backup given host
EOF
}

if [ $# -lt 1 ]; then
    show_usage
    exit 1
fi

IP="$1"
if ! ping -c 1 -n -w 1 $IP >/dev/null 2>&1 ; then
    echo "Could not ping $IP"
    exit 1
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
bkp_load_env "openwrt_$IP"
bkp_verify_env

if [ -z ${LUCI_PASSWORD+x} ]; then
    echo "LUCI_PASSWORD is unset"
    exit 3
fi

NAME="openwrt_${IP}-$(date +%Y%m%d_%H%M%S)"
log="${HOME}/bkp-${NAME}.log.zst"
echo "LOG: $log"
echo "NAME: $NAME"

restic version \
  2>&1 | tee >(zstd -T0 --long >> "$log")
restic init \
  2>&1 | tee >(zstd -T0 --long >> "$log") \
  || true

URL="http://${IP}/cgi-bin"
f=$(mktemp)
routerpswd="luci_username=root&luci_password=$LUCI_PASSWORD"
sessionid=$(curl --silent --data-raw "$routerpswd" -c - "${URL}/luci" | grep sysauth | sed -r 's/.*sysauth\s*//')
curl "${URL}/cgi-backup" --data-raw "sessionid=${sessionid}" \
        | restic \
        --verbose \
        --no-cache \
        --tag="openwrt" \
        --tag="stream" \
        --tag="${IP}" \
        --stdin \
        --stdin-filename="${NAME}.tgz" \
        backup \
  2>&1 | tee >(zstd -T0 --long >> "$log")

exit 0
