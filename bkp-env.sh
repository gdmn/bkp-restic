#! /usr/bin/env bash

CONFIGURATION_DIR="$HOME/.config/bkp-restic"

show_help() {
cat << EOF
Restic backup environment.

Usage:
    $(basename $0) --help - help and usage
    . $(basename $0) --no-auto - import \`bkp_setup_env\` function for later use
    . $(basename $0) host - import backup environment for a given host
EOF
}

bkp_setup_env() {
	export REMOTE_HOST="$1"
	echo "Loading configuration for $REMOTE_HOST"
	if [ ! -d $CONFIGURATION_DIR ] ; then
		echo "Configuration folder $CONFIGURATION_DIR is not present"
		exit 2
	fi
	if [ -f $CONFIGURATION_DIR/main.conf ] ; then
		echo "Loading $CONFIGURATION_DIR/main.conf"
		pushd "$CONFIGURATION_DIR" >/dev/null 2>&1
		. "main.conf"
		popd >/dev/null 2>&1
	fi
	if [ -f $CONFIGURATION_DIR/$REMOTE_HOST.conf ] ; then
		echo "Loading $CONFIGURATION_DIR/$REMOTE_HOST.conf"
		pushd "$CONFIGURATION_DIR" >/dev/null 2>&1
		. "$REMOTE_HOST.conf"
		popd >/dev/null 2>&1
	fi

	if [ -z ${BKP_RESTIC_PASSWORD+x} ]; then
		echo "BKP_RESTIC_PASSWORD is unset"
		exit 3
	fi
	if [ -z ${BKP_REST_RESTIC_REPOSITORY+x} ]; then
		echo "BKP_REST_RESTIC_REPOSITORY is unset"
		exit 3
	fi

	export RESTIC_REPOSITORY="${BKP_REST_RESTIC_REPOSITORY}"
	export RESTIC_PASSWORD="${BKP_RESTIC_PASSWORD}"

	if [ ! -z ${BKP_REAL_PATH_RESTIC_REPOSITORY+x} ]; then
		if [ -d "${BKP_REAL_PATH_RESTIC_REPOSITORY}${REMOTE_HOST}" ]; then
			echo "Using existing directory ${BKP_REAL_PATH_RESTIC_REPOSITORY}${REMOTE_HOST}"
			export RESTIC_REPOSITORY="${BKP_REAL_PATH_RESTIC_REPOSITORY}${REMOTE_HOST}"
		fi
	fi
}

if [[ "$1" == "--help" ]]; then
	show_help
elif [[ "$1" == "--no-auto" ]]; then
	true
elif [ $# -eq 1 ]; then
	bkp_setup_env $1
else
	command -v hostnamectl >/dev/null 2>&1 && \
	bkp_setup_env "$(hostnamectl status --transient)" || \
	echo >&2 "Required command hostnamectl is not installed."
fi
