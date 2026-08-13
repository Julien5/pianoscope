#!/usr/bin/env bash

function main() {
	export RUST_LOG=trace
	# cargo run -- wav-file  data/C4.wav
	cargo run -- midi 0
	# cargo run -- microphone
}

main "$@"
