#!/usr/bin/env bash

set -e
# set -x

function parse-arguments() {
	TARGET=test
	while [[ $# -gt 0 ]]; do
		case $1 in
			--test-detection)
				TARGET=test-detection
				shift
				;;
			--test-detection-all)
				TARGET=test-detection-all
				shift
				;;
			--test-all)
				TARGET=test
				shift
				;;
			-*|--*)
				echo "Unknown option $1"
				exit 1
				;;
		esac
	done
}

function run-test-detection() {
	ffprobe -v error -show_entries stream=sample_rate,duration -of default=noprint_wrappers=1 \
			~/delme/old-piano-recordings/position-1/C1/mark-4-C.wav
	2>&1 cargo test -- --nocapture piano_some | tee /tmp/test.log | cut -f2- -d"]"
}

function run-test-detection-all() {
	ffprobe -v error -show_entries stream=sample_rate,duration -of default=noprint_wrappers=1 \
			~/delme/old-piano-recordings/position-1/C1/mark-4-C.wav
	2>&1 cargo test -- --nocapture piano_all | tee /tmp/test.log | cut -f2- -d"]"
	echo bad position-1: $(cat /tmp/old-piano-bad.txt  | grep position-1 | wc -l)
	echo bad position-2: $(cat /tmp/old-piano-bad.txt  | grep position-2 | wc -l)
}

function run-test() {
	cargo test
}

function main() {
	export RUST_LOG=trace
	run-$TARGET
	# cargo run -- wav-file  data/D4.wav 
	# cargo run -- midi 0
	#cargo run -- simulation 1
	# cargo run -- microphone
}

parse-arguments "$@"
main "$@"
