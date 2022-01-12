#! /usr/bin/env bash

set -e

command -v restic >/dev/null 2>&1 || { echo >&2 "Required command restic is not installed."; exit 1; }
command -v zstd >/dev/null 2>&1 || { echo >&2 "Required command zstd is not installed."; exit 1; }

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
log="$HOME/bkp-prune-$(date +%Y%m%d_%H%M%S).log.zst"
echo "LOG: $log"

processRepoClean() {
	restic unlock \
	  -r "$1" \
	  2>&1 | tee >(zstd -T0 --long >> "$log")

	# keep daily snapshots for a week, weekly for a month, monthly for a year and yearly for 2 years:
	ionice -c 2 -n 7 nice -n 19 \
	restic forget --prune --verbose \
	  --cleanup-cache \
	  -r "$1" \
	  --keep-within-daily 7d --keep-within-weekly 1m --keep-within-monthly 1y --keep-within-yearly 2y \
	  --keep-last 7 \
	  2>&1 | tee >(zstd -T0 --long >> "$log")

	ionice -c 2 -n 7 nice -n 19 \
	restic check --read-data-subset=9.9% \
	  -r "$1" \
	  2>&1 | tee >(zstd -T0 --long >> "$log")
}

processRepoKeepOneClean() {
	restic unlock \
	  -r "$1" \
	  2>&1 | tee >(zstd -T0 --long >> "$log")

	ionice -c 2 -n 7 nice -n 19 \
	restic forget --keep-last 1 \
	  -r "$1" \
	  2>&1 | tee >(zstd -T0 --long >> "$log")

	ionice -c 2 -n 7 nice -n 19 \
	restic prune --max-unused 0 \
	  -r "$1" \
	  2>&1 | tee >(zstd -T0 --long >> "$log")
}

find "$BKP_REAL_PATH_RESTIC_REPOSITORY" -mindepth 0 -maxdepth 3 -name 'snapshots' -type d | \
while read k ; do
	dir="$(dirname $k)"
	if [ -r "${dir}/config" ] ; then
		echo "${dir}"
	fi
done | \
while read repo ; do
	processRepoClean "$repo"
	#processRepoKeepOneClean "$repo"
done
