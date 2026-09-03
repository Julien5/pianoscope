#!/usr/bin/env python3
"""Print the main (fundamental) frequency of a wav file, e.g. '261 Hz'."""

import argparse
import sys
import wave

import numpy as np


def read_wav(path):
    with wave.open(str(path), "rb") as w:
        channels = w.getnchannels()
        sampwidth = w.getsampwidth()
        rate = w.getframerate()
        raw = w.readframes(w.getnframes())
    dtype = {1: np.int8, 2: np.int16, 4: np.int32}[sampwidth]
    data = np.frombuffer(raw, dtype=dtype).astype(np.float32)
    data = data.reshape(-1, channels)
    data /= np.iinfo(dtype).max
    mono = data.mean(axis=1)
    return mono, rate


def main_frequency(mono, rate):
    m = mono - np.mean(mono)
    n = m.size
    a = np.fft.rfft(m, n=1 << (2 * n - 1).bit_length())
    ac = np.fft.irfft(a * np.conj(a))[:n]
    if ac[0] != 0:
        ac /= ac[0]

    lo = int(rate / 1500)
    hi = int(rate / 20)
    if hi > len(ac):
        hi = len(ac)
    if hi <= lo:
        return None
    lag = lo + int(np.argmax(ac[lo:hi]))
    return rate / lag


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("input", help="input wav file")
    args = ap.parse_args()

    try:
        mono, rate = read_wav(args.input)
    except Exception as e:
        print(f"error: {e}", file=sys.stderr)
        sys.exit(1)

    if len(mono) < 2:
        print("error: file too short", file=sys.stderr)
        sys.exit(1)

    f = main_frequency(mono, rate)
    if f is None or f <= 0:
        print(f"error: could not estimate frequency for {args.input}", file=sys.stderr)
        sys.exit(1)

    print(f"{round(f)} Hz")


if __name__ == "__main__":
    main()