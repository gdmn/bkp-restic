#! /usr/bin/env bash

set -e

command -v restic >/dev/null 2>&1 || { echo >&2 "Required command restic is not installed."; exit 1; }
command -v hostnamectl >/dev/null 2>&1 || { echo >&2 "Required command hostnamectl is not installed."; exit 1; }
command -v zstd >/dev/null 2>&1 || { echo >&2 "Required command zstd is not installed."; exit 1; }

CONFIGURATION_DIR="$HOME/.config/bkp-restic"
export REMOTE_HOST="$(hostnamectl status --transient)"

show_help() {
cat << EOF
Restic backup

Usage:
    $(basename $0) --help - help and usage
    $(basename $0) - execute restic backup

Main configuration file: $CONFIGURATION_DIR/main.conf
Host specific configuration file: $CONFIGURATION_DIR/$REMOTE_HOST.conf

Example configuration:
    export BKP_RESTIC_PASSWORD='abc'
    export BKP_REST_RESTIC_REPOSITORY="rest:http://admin:password@backuphost:8000/\$REMOTE_HOST"
    export BKP_RESTIC_INCLUDE_FILES="\$CONFIGURATION_DIR/bkp-include.txt"
    export BKP_RESTIC_EXCLUDE_FILES="\$CONFIGURATION_DIR/bkp-exclude.txt"

For more information, see https://github.com/gdmn/bkp-restic/blob/main/README.md
EOF
}

if [[ "$1" == "--help" ]]; then
	show_help
	exit 0
fi

RESTIC_EXE="restic"
SUDO_RESTIC_EXE="sudo restic"

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
if [ -z ${BKP_RESTIC_INCLUDE_FILES+x} ]; then
	echo "BKP_RESTIC_INCLUDE_FILES is unset"
	exit 3
fi
if [ -z ${BKP_RESTIC_EXCLUDE_FILES+x} ]; then
	echo "BKP_RESTIC_EXCLUDE_FILES is unset"
	exit 3
fi
if [ ! -r ${BKP_RESTIC_INCLUDE_FILES} ]; then
	echo "$BKP_RESTIC_INCLUDE_FILES is not readable"
	exit 3
fi
if [ ! -r ${BKP_RESTIC_EXCLUDE_FILES} ]; then
	echo "$BKP_RESTIC_EXCLUDE_FILES is not readable"
	exit 3
fi

log="${HOME}/bkp-${REMOTE_HOST}-$(date +%Y%m%d_%H%M%S).log.zst"
echo "LOG: $log"

if [[ "$RESTIC_REPOSITORY" == "sftp:"* ]] ; then
	dir=${RESTIC_REPOSITORY//*:/}
	srv=${RESTIC_REPOSITORY//:\/*/}
	srv=${srv//*:/}
	echo "dir: $dir"
	echo "srv: $srv"
	ssh -t $srv "mkdir -p $dir"
fi

$RESTIC_EXE version \
  2>&1 | tee >(zstd -T0 --long >> "$log")
$RESTIC_EXE init \
  2>&1 | tee >(zstd -T0 --long >> "$log") \
  || true

ionice -c 2 -n 7 nice -n 19 \
$SUDO_RESTIC_EXE -vvv backup \
  --files-from "$BKP_RESTIC_INCLUDE_FILES" \
  --iexclude-file "$BKP_RESTIC_EXCLUDE_FILES" \
  --exclude-if-present .exclude_from_restic_bkp \
  --one-file-system \
  2>&1 | tee >(zstd -T0 --long >> "$log") \
  | grep -v '^unchanged ' | grep -v '0 B added'
