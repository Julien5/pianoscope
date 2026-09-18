# The kord pitch/chord detection algorithm

Source: `kord` crate v0.8, `src/analyze/base.rs` (algorithm) + `src/core/note.rs`,
`pitch.rs`, `interval.rs` (note table and harmonics). Ported (and adapted) into
`backend/src/microphone/detection/kord.rs`.

## Purpose

Given a buffer of mono `f32` audio samples, return the set of notes (a chord)
that are present, i.e. **polyphonic** pitch detection. This is different from the
other detectors in `algorithms.rs` (McLeod, YIN, PYIN, Swipe, autocorrelation),
which are monophonic and return a single best pitch.

## Input contract (original)

```
get_notes_from_audio_data(data: &[f32], length_in_seconds: u8) -> Vec<Note>
```

The audio buffer must be **exactly `length_in_seconds` seconds** at the stream's
sample rate (i.e. `data.len() == sample_rate * length_in_seconds`), with
`length_in_seconds >= 1`. This is baked into the math: with `N` samples at sample
rate `sr`, the FFT bin width is `sr / N = 1 / length_in_seconds` Hz, so bin `k`
lies at frequency `k / length_in_seconds` Hz. The algorithm then re-bins the
spectrum to a uniform **1 Hz grid** (the `get_smoothed_frequency_space` step).

## Pipeline

1. **FFT** — full-buffer forward FFT via `rustfft` (`FftPlanner`). The magnitude
   spectrum is produced as `(frequency, magnitude)` pairs.

2. **Smooth / re-bin to 1 Hz** — group `length_in_seconds` consecutive bins and
   average each group (frequency and magnitude). For a 1 s buffer this is the
   identity; for longer buffers it decimates the raw bins down to 1 Hz resolution.

3. **Peak detection** (`translate_frequency_space_to_peak_space`):
   - Scan the spectrum only between 50 Hz and 8000 Hz (piano/vocal range).
   - For each bin, use a window whose width scales with frequency
     (`window_size = freq / 50` bins, i.e. ~1/3 of a semitone). Within each window
     keep the local maximum as a peak, zero out everything else.
   - Then zero out peaks whose relative first derivative is small
     (`|d mag / d freq| / mag < 0.1`): sharp peaks are tones, flat/smooth bumps are
     noise.

4. **Peak → note matching** (`get_likely_notes_from_peak_space`):
   - Keep peaks with magnitude above a floor (`> 0.1`) and above 10% of the
     strongest peak (`> max * 0.1`).
   - Map each surviving peak to the nearest note via `binary_search_closest` over
     a precomputed table of 192 note frequencies (16 octaves × 12 pitches, C0..B15).
   - Accumulate magnitude per note (multiple peaks may map to the same note).

5. **Harmonic folding** (`reduce_notes_by_harmonic_series`):
   - For each note, if another detected note is one of its *primary harmonics*
     (the 2nd..7th and 9th..15th harmonics), absorb the harmonic's magnitude into
     the fundamental and remove the harmonic from the result.
   - Re-sort by magnitude and drop notes below 10% of the strongest remaining note.
   - This is how chord detection works: a C major chord's peaks land on C, E, G,
     but the harmonics of C (which coincide with E and G's octaves) are folded into
     C, so the output is the chord's fundamentals.

6. **Output** — a `Vec<Note>`, strongest first (in the port, `Vec<(frequency,
   magnitude)>` so confidence = magnitude / max).

## The note table and harmonic series

The note frequency table is built from 12 base frequencies (rounded equal-temperament
values at octave 0) and `frequency = base[pitch] * 2^octave`:

```
C 16.35   Db 17.32  D 18.35  Eb 19.45  E 20.60  F 21.83
Gb 23.12  G 24.50   Ab 25.96  A 27.50  Bb 29.14  B 30.87
```

The primary harmonic series of a note is computed by adding 13 fixed intervals
(each expressed as a circle-of-fifths step plus an octave component):

```
PerfectOctave                     (0, 1)
PerfectOctaveAndPerfectFifth      (1, 1)
TwoPerfectOctaves                 (0, 2)
TwoPerfectOctavesAndMajorThird    (4, 2)
TwoPerfectOctavesAndPerfectFifth  (1, 2)
TwoPerfectOctavesAndMinorSeventh (-2, 2)
ThreePerfectOctavesAndMajorSecond (2, 3)
ThreePerfectOctavesAndMajorThird  (4, 3)
ThreePerfectOctavesAndAugFourth   (6, 3)
ThreePerfectOctavesAndPerfectFifth (1, 3)
ThreePerfectOctavesAndMinorSixth (-4, 3)
ThreePerfectOctavesAndMinorSeventh (-2, 3)
ThreePerfectOctavesAndMajorSeventh (5, 3)
```

Pitch classes are moved on the circle of fifths (`FIFTH_INDEX`), which preserves
enharmonic correctness, plus a wrap octave and a rare "special" octave adjustment
(only root E♭ + minor-sixth harmonic ever triggers it for the table's flat-side
spellings). Frequencies are compared with **exact `==`** during folding, which is
why the same rounded table and computation path must be used throughout.

## Properties / tradeoffs

- **Polyphonic**: returns a chord, not a single pitch.
- **Weak fundamentals are a weakness**: harmonic folding only folds *upward* into a
  fundamental that is *already a detected peak*. If a low note's fundamental is
  weak relative to its harmonics (common on real pianos), the detector locks onto
  the 2nd harmonic — a pure **octave error** (e.g. a C2 recording is detected as
  C3). This is window-independent and was confirmed at 125 ms, 500 ms and 1 s.
- **50 Hz scan floor**: notes below ~50 Hz (C1 and below) are never detected,
  regardless of window length.
- **Resolution vs latency**: FFT bin width = 1 / window duration. 1 s window →
  1 Hz bins (can resolve a semitone down to ~17 Hz); 125 ms → 8 Hz bins (resolves
  a semitone only above ~70 Hz).

## The port (`backend/src/microphone/detection/kord.rs`)

Adaptations vs the original kord code:

- `analyze(data: &[f32], sample_rate: u32) -> Vec<(freq, magnitude)>` — the integer
  `length_in_seconds` contract is dropped; `bin_width = sample_rate / data.len()`
  is derived from the actual buffer, so any window length (≥ 32 samples) works.
- The "smooth to 1 Hz" step is removed (meaningless below 1 s).
- Peak-scan bounds and the peak/derivative windows are rescaled from Hz to bins
  (`min_index = ceil(50/bin_width)`, `max_index = ceil(8000/bin_width)`,
  peak window `max(1, (freq/50)/bin_width)`, derivative window
  `max(1, round(3/bin_width))`).
- A **Hann window** is applied before the FFT (kord uses a rectangular window) to
  suppress spectral leakage, which would otherwise create false adjacent notes at
  short windows.
- Empty-input guards were added (kord would panic on `peak_space[0]`/`working_set[0]`
  for silence).
- Returns magnitudes so downstream confidence = magnitude / max.

The consumer is `KordDetector` in `algorithms.rs`: it maintains a ring buffer of
`sample_rate * duration_seconds` samples (default = the block length, 125 ms,
configurable via `set_duration`), runs `analyze` per block, and emits one
`Estimate` per detected note.