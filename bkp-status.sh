#! /usr/bin/env bash

set -e

command -v restic >/dev/null 2>&1 || { echo >&2 "Required command restic is not installed."; exit 1; }

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
bkp_load_env bkp-prune

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

processRepoSnapshots() {
	echo -n "$1: "
	restic snapshots \
		--no-lock --compact \
		-r "$1" || true
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
