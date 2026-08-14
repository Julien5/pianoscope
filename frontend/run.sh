#!/usr/bin/env bash

#set -euo pipefail
# set -x

function init() {
	SCRIPTDIR=$(realpath $(dirname $0))
	PROJECTDIR=$(pwd)
	source ~/.profile || true
}

function parse-arguments() {
	TARGET=
	SIMULATION=
	while [[ $# -gt 0 ]]; do
		case $1 in
			--target)
				TARGET=$2
				shift
				shift
				;;
			--simulation)
				SIMULATION=$2
				shift
				shift
				;;
			-*|--*)
				echo "Unknown option $1"
				exit 1
				;;
		esac
	done
	if [ -z ${TARGET} ]; then
		echo "run.sh --target TARGET"
		echo "TARGET: android-arm64 android-x64 linux"
		return 1
	fi
}

function load-toolchain() {
	source ~/projects/config/profile/profile.rust.sh
	source ~/projects/config/profile/profile.flutter.sh
	case "$TARGET" in
		android-*)
			source ~/projects/config/profile/profile.android.sh
			;;
	esac
}

function need-generate() {
	BRIDGEDIR=${SCRIPTDIR}/rust 
	GENERATEDDIR=${SCRIPTDIR}/lib/src/rust 

	if [ ! -d "$GENERATEDDIR" ]; then
		return 0
	fi

	TIMEBRIDGE=$(find "$BRIDGEDIR" -type f -printf '%T@\n' 2>/dev/null | sort -nr | head -n 1)
	TIMEGEN=$(find "$GENERATEDDIR" -type f -printf '%T@\n' 2>/dev/null | sort -nr | head -n 1)

	if [ -z "$TIMEBRIDGE" ]; then
		return 0
	fi

	if [ -z "$TIMEGEN" ]; then
		return 0
	fi

	# Compare the timestamps using floating-point comparison via bc (or integer part)
	# We strip decimals for standard integer comparison in Bash:
	TBRIDGE=${TIMEBRIDGE%.*}
	TGEN=${TIMEGEN%.*}
	if [ "$TBRIDGE" -gt "$TGEN" ]; then
		# bridge was modified
		return 0
	fi
	# bridge was not modified
	return 1;
}

function pixel() {
	# connect: wlan
	#     adb connect 192.168.1.100:35309
	#     connected to 192.168.1.100:35309
	# usb: 25131JEGR02219
	# lan: 192.168.1.101:38449
	if [ -f /tmp/PIXEL ]; then
		cat /tmp/PIXEL
		return;
	fi
	echo 192.168.1.101:38449
}

function setup-simulation() {
	if [ -z "${SIMULATION}" ]; then
		case "$TARGET" in
			android*)
				adb shell "setprop debug.frontend.simulation ''"
				;;
		esac
		return
	fi
	
	case "$TARGET" in
		android*)
			adb shell setprop debug.frontend.simulation ${SIMULATION}
			;;
		linux)
			export SIMULATION=${SIMULATION}
	esac
}

function main() {
	load-toolchain
	MODE=debug
	if need-generate; then
		echo bindings need to be re-generated
		flutter_rust_bridge_codegen generate
	else
		echo bindings are up-to-date
	fi
	# TODO: check if needed 
	~/projects/notes/tools/build.sh --target ${TARGET} --mode ${MODE}
	setup-simulation
	case "$TARGET" in
		android-arm64)
			flutter run -d $(pixel) --${MODE}
			;;
		android-x64)
			# flutter run -d emulator-pixel-6a --${MODE}
			flutter run -d emulator-pixel6a-root --${MODE} 
			;;
		linux)
			flutter run -d linux --${MODE}
			;;
	esac
}

init 
if parse-arguments "$@"; then
	main 
fi

