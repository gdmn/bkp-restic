#! /usr/bin/env bash

set -e

command -v restic >/dev/null 2>&1 || { echo >&2 "Required command restic is not installed."; exit 1; }

CONFIGURATION_DIR="$HOME/.config/bkp-restic"
if [ -f $CONFIGURATION_DIR/main.conf ] ; then
	echo "Loading $CONFIGURATION_DIR/main.conf"
	pushd "$CONFIGURATION_DIR" >/dev/null 2>&1
	. "main.conf"
	popd >/dev/null 2>&1
fi
if [ -z ${BKP_RESTIC_PASSWORD+x} ]; then
	echo "BKP_RESTIC_PASSWORD is unset"
	exit 3
fi
if [ -z ${BKP_REAL_PATH_RESTIC_REPOSITORY+x} ]; then
	echo "Repository folder $BKP_REAL_PATH_RESTIC_REPOSITORY is unset"
	exit 3
fi
if [ ! -d "${BKP_REAL_PATH_RESTIC_REPOSITORY}" ]; then
	echo "Repository folder $BKP_REAL_PATH_RESTIC_REPOSITORY is not present"
	exit 2
fi

export RESTIC_PASSWORD="${BKP_RESTIC_PASSWORD}"
SCRIPT_DIR="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

processRepoSnapshots() {
	echo "$1"
	restic snapshots \
		--compact \
		-r "$1" \
		| grep "$(basename $1)" || echo "ERROR" && true
}

find "$BKP_REAL_PATH_RESTIC_REPOSITORY" -mindepth 0 -maxdepth 3 -name 'snapshots' -type d | \
while read k ; do
	dir="$(dirname $k)"
	if [ -r "${dir}/config" ] ; then
		echo "${dir}"
	fi
done | \
while read repo ; do
	processRepoSnapshots "$repo"
done
