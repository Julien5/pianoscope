#!/usr/bin/env python3
"""Split a wav file into notes, using silence gaps as separators."""

import argparse
import wave
from pathlib import Path

import numpy as np


def read_wav(path):
    with wave.open(str(path), "rb") as w:
        channels = w.getnchannels()
        sampwidth = w.getsampwidth()
        rate = w.getframerate()
        nframes = w.getnframes()
        raw = w.readframes(nframes)
    dtype = {1: np.int8, 2: np.int16, 4: np.int32}[sampwidth]
    data = np.frombuffer(raw, dtype=dtype).astype(np.float32)
    data = data.reshape(-1, channels)
    data /= np.iinfo(dtype).max
    mono = data.mean(axis=1)
    return data, mono, rate, sampwidth, channels


def write_wav(path, data, rate, sampwidth, channels):
    dtype = {1: np.int8, 2: np.int16, 4: np.int32}[sampwidth]
    info = np.iinfo(dtype)
    scaled = np.clip(data, -1.0, 1.0) * info.max
    raw = scaled.astype(dtype).tobytes()
    with wave.open(str(path), "wb") as w:
        w.setnchannels(channels)
        w.setsampwidth(sampwidth)
        w.setframerate(rate)
        w.writeframes(raw)


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("input", help="input wav file (e.g. position-1/C1/all.wav)")
    ap.add_argument(
        "-o", "--output-dir", default=None,
        help="output directory (default: same dir as input)",
    )
    ap.add_argument(
        "-t", "--threshold", type=float, default=0.01,
        help="RMS amplitude below which a frame is considered silence (default: 0.01)",
    )
    ap.add_argument(
        "-w", "--window-ms", type=float, default=20,
        help="analysis window length in ms (default: 20)",
    )
    ap.add_argument(
        "-g", "--min-gap-ms", type=float, default=120,
        help="minimum silence gap in ms to split on (default: 120)",
    )
    ap.add_argument(
        "-p", "--pad-ms", type=float, default=20,
        help="padding in ms kept around each note (default: 20)",
    )
    ap.add_argument(
        "-n", "--name-prefix", default="note",
        help="output file name prefix (default: note)",
    )
    args = ap.parse_args()

    data, mono, rate, sampwidth, channels = read_wav(args.input)

    window = max(1, int(rate * args.window_ms / 1000))
    min_gap = max(1, int(rate * args.min_gap_ms / 1000))
    pad = int(rate * args.pad_ms / 1000)

    rms = np.sqrt(
        np.convolve(mono**2, np.ones(window) / window, mode="same")
    )
    is_silence = rms < args.threshold

    runs = []
    run_start = 0
    prev = is_silence[0]
    for i, sil in enumerate(is_silence[1:], start=1):
        if sil != prev:
            runs.append((run_start, i, prev))
            run_start = i
            prev = sil
    runs.append((run_start, len(is_silence), prev))

    if runs[0][2]:
        runs = runs[1:]
    if runs and runs[-1][2]:
        runs = runs[:-1]

    segments = []
    for start, end, silent in runs:
        if not silent:
            if segments and start - segments[-1][1] < min_gap:
                segments[-1] = (segments[-1][0], end)
            else:
                segments.append((start, end))
    if not segments:
        print(f"no notes detected in {args.input} (threshold={args.threshold})")
        return

    out_dir = Path(args.output_dir) if args.output_dir else Path(args.input).parent
    out_dir.mkdir(parents=True, exist_ok=True)
    prefix = args.name_prefix

    print(f"{args.input}: {len(segments)} notes detected")
    for n, (s, e) in enumerate(segments, 1):
        s = max(0, s - pad)
        e = min(len(data), e + pad)
        out = out_dir / f"{prefix}_{n:03d}.wav"
        write_wav(out, data[s:e], rate, sampwidth, channels)
        print(f"  {out}  {e - s} samples ({1e3 * (e - s) / rate:.1f} ms)")


if __name__ == "__main__":
    main()
