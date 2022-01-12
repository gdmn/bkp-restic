#! /usr/bin/env bash

CONFIGURATION_DIR="$HOME/.config/bkp-restic"

show_usage() {
cat << EOF
Restic pull backup

Usage:
    $(basename $0) --help - help and usage
    $(basename $0) host - open ssh connection to host and execute restic remotely

Main configuration file: $CONFIGURATION_DIR/main.conf
Host specific configuration file: $CONFIGURATION_DIR/host.conf
    ("host" is the same value as the first argument to this script)
EOF
}

show_help() {
cat << EOF

Example configuration:
    export BKP_RESTIC_PASSWORD='abc'
    export BKP_FORWARDED_RESTIC_REPOSITORY="rest:http://admin:password@localhost:60008/\$REMOTE_HOST"
    export BKP_SSH_FORWARD_RULE='60008:backuphost:8000'
    export BKP_RESTIC_INCLUDE_FILES="\$CONFIGURATION_DIR/bkp-include.txt"
    export BKP_RESTIC_EXCLUDE_FILES="\$CONFIGURATION_DIR/bkp-exclude.txt"

Example configuration explenation:
    BKP_SSH_FORWARD_RULE is the SSH remote forward rule.
    "backuphost:8000" is the actual address of restic-rest server instance.
    BKP_RESTIC_INCLUDE_FILES and BKP_RESTIC_EXCLUDE_FILES contain include
    and exclude patterns, exclude file patterns are case insensitive.

For more information, see https://github.com/gdmn/bkp-restic/blob/main/README.md
EOF
}

set -e

if [ $# -lt 1 ]; then
	show_usage
	exit 1
fi

if [[ "$1" == "--help" ]]; then
	show_usage
	show_help
	exit 0
fi

REMOTE_HOST="$1"
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

if [ -z ${BKP_RESTIC_PASSWORD+x} ]; then
	echo "BKP_RESTIC_PASSWORD is unset"
	exit 3
fi
if [ -z ${BKP_FORWARDED_RESTIC_REPOSITORY+x} ]; then
	echo "BKP_FORWARDED_RESTIC_REPOSITORY is unset"
	exit 3
fi
if [ -z ${BKP_SSH_FORWARD_RULE+x} ]; then
	echo "BKP_SSH_FORWARD_RULE is unset"
	exit 3
fi
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

SSH_CONTROL_SOCKET="$(mktemp)"
SSH="ssh -R $BKP_SSH_FORWARD_RULE -S $SSH_CONTROL_SOCKET $REMOTE_HOST"

echo -n 'waiting for ssh...'
until $SSH -o ConnectTimeout=1 -o ConnectionAttempts=1 -t true >/dev/null 2>&1; do
	echo -n '.'
	sleep 3
done
echo ' ok'

REMOTE_TEMP_DIR=$($SSH "mktemp -d")
cat "$BKP_RESTIC_INCLUDE_FILES" | $SSH "cat > ${REMOTE_TEMP_DIR}/include.txt"
cat "$BKP_RESTIC_EXCLUDE_FILES" | $SSH "cat > ${REMOTE_TEMP_DIR}/exclude.txt"
$SSH "mkfifo $REMOTE_TEMP_DIR/repository1"
echo "$BKP_FORWARDED_RESTIC_REPOSITORY" | $SSH "cat > ${REMOTE_TEMP_DIR}/repository1" &
$SSH "mkfifo $REMOTE_TEMP_DIR/repository2"
echo "$BKP_FORWARDED_RESTIC_REPOSITORY" | $SSH "cat > ${REMOTE_TEMP_DIR}/repository2" &
$SSH "mkfifo $REMOTE_TEMP_DIR/password1"
echo "$BKP_RESTIC_PASSWORD" | $SSH "cat > ${REMOTE_TEMP_DIR}/password1" &
$SSH "mkfifo $REMOTE_TEMP_DIR/password2"
echo "$BKP_RESTIC_PASSWORD" | $SSH "cat > ${REMOTE_TEMP_DIR}/password2" &

$SSH "mkfifo $REMOTE_TEMP_DIR/fifo"
cat << EOF | $SSH "cat > ${REMOTE_TEMP_DIR}/fifo" &
set -e
command -v restic >/dev/null 2>&1 || { echo >&2 "Required command restic is not installed."; exit 1; }

A='script'
echo \$A loaded

$RESTIC_EXE version
$RESTIC_EXE init \
  --repository-file "${REMOTE_TEMP_DIR}/repository1" \
  --password-file "${REMOTE_TEMP_DIR}/password1" \
  || true
$SUDO_RESTIC_EXE -vvv backup \
  --repository-file "${REMOTE_TEMP_DIR}/repository2" \
  --password-file "${REMOTE_TEMP_DIR}/password2" \
  --files-from "${REMOTE_TEMP_DIR}/include.txt" \
  --iexclude-file "${REMOTE_TEMP_DIR}/exclude.txt" \
  --exclude-if-present .exclude_from_restic_bkp \
  --one-file-system \
  2>&1 \
  | grep -v '^unchanged ' | grep -v '0 B added'
EOF

$SSH -t "bash ${REMOTE_TEMP_DIR}/fifo" \
  || true
$SSH "rm -rf $REMOTE_TEMP_DIR"
$SSH -O exit
rm -f $SSH_CONTROL_SOCKET
