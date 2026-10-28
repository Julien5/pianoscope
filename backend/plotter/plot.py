import os
import subprocess

import numpy as np

DOWNSAMPLE_FACTOR = 16
WINDOW_SECONDS = 10.0
MIN_PLOT_INTERVAL = 0.5
AUDIO_CSV_PATH = "/tmp/audio.csv"
PITCH_CSV_PATH = "/tmp/pitch.csv"
NOTES_CSV_PATH = "/tmp/notes.csv"
PLOT_PNG_PATH = "/tmp/plot.png"
RENDER_SCRIPT_PATH = "/tmp/plot.gp"
PLOT_SCRIPT_PATH = os.path.join(os.path.dirname(__file__), "plot.gnuplot")


def _sample_rate(buffer):
    return buffer[-1].audio.sample_rate if buffer else 0


def _display_samples(buffer):
    return sum(p.audio.num_samples for p in buffer) // DOWNSAMPLE_FACTOR


def trim_buffer(buffer, window_seconds=WINDOW_SECONDS):
    rate = _sample_rate(buffer)
    if rate == 0:
        return
    max_display = rate / DOWNSAMPLE_FACTOR * window_seconds
    while _display_samples(buffer) > max_display:
        buffer.popleft()


def _flatten_samples(buffer):
    arrays = [p.audio.samples(step=DOWNSAMPLE_FACTOR) for p in buffer]
    if not arrays:
        return np.array([])
    return np.concatenate(arrays)


def save_data_csv(buffer_data, path=AUDIO_CSV_PATH):
    """Write the down-sampled samples as (t, value) rows. Returns the row count."""
    samples = _flatten_samples(buffer_data)
    if len(samples) == 0:
        return 0

    display_freq = _sample_rate(buffer_data) / DOWNSAMPLE_FACTOR
    tmp_path = "/tmp/tmp_data.csv"
    with open(tmp_path, "w", newline="", encoding="utf-8") as f:
        f.write("# t (s), value (downsampled)\n")
        for index, value in enumerate(samples):
            f.write(f"{index / display_freq:.6f} {value}\n")

    os.replace(tmp_path, path)
    return len(samples)


def save_pitch_csv(buffer, path=PITCH_CSV_PATH):
    """Write one row per audio block with the PitchDetector data (energy, threshold)."""
    if not buffer:
        return

    display_freq = _sample_rate(buffer) / DOWNSAMPLE_FACTOR
    tmp_path = "/tmp/tmp_pitch.csv"
    with open(tmp_path, "w", newline="", encoding="utf-8") as f:
        f.write("# start_x, center_x, width, energy, threshold, level_min, level_max\n")
        pos = 0
        for packet in buffer:
            n = len(packet.audio.samples(step=DOWNSAMPLE_FACTOR))
            if n == 0:
                continue
            start = pos / display_freq
            center = (pos + n / 2) / display_freq
            width = n / display_freq
            energy = packet.audio.pitch_detector.energy
            confidence = packet.audio.pitch_detector.confidence-0.9
            threshold = packet.audio.pitch_detector.threshold
            level_min = packet.audio.pitch_detector.level_min;
            level_max = packet.audio.pitch_detector.level_max;
            f.write(f"{start:.6f} {center:.6f} {width:.6f} {energy:.6f} {threshold:.6f} {level_min:.6f} {level_max:.6f} {confidence:.6f}\n")
            pos += n

    os.replace(tmp_path, path)


def save_notes_csv(buffer, path=NOTES_CSV_PATH):
    """Write one row per stable note segment as (center_x, note)."""
    if not buffer:
        return

    display_freq = _sample_rate(buffer) / DOWNSAMPLE_FACTOR
    tmp_path = "/tmp/tmp_notes.csv"
    rows = []
    pos = 0
    segment_start = 0
    segment_note = None

    def flush(end_pos):
        if segment_note:
            center = ((segment_start + end_pos) / 2) / display_freq
            rows.append((center, segment_note))

    for packet in buffer:
        n = len(packet.audio.samples(step=DOWNSAMPLE_FACTOR))
        if n == 0:
            continue
        note = packet.audio.pitch_detector.current
        if True or note != segment_note:
            flush(pos)
            segment_note = note
            segment_start = pos
        pos += n
    flush(pos)

    with open(tmp_path, "w", newline="", encoding="utf-8") as f:
        f.write("# center_x, note\n")
        for center, note in rows:
            f.write(f"{center:.6f} {note}\n")

    os.replace(tmp_path, path)


def render_plot(buffer, output_path=PLOT_PNG_PATH):
    if len(buffer) == 0:
        return

    count = save_data_csv(buffer)
    save_pitch_csv(buffer)
    save_notes_csv(buffer)

    with open(PLOT_SCRIPT_PATH) as f:
        script = f.read().format(
            count=count,
            WINDOW_SECONDS=WINDOW_SECONDS,
            audio_csv=AUDIO_CSV_PATH,
            pitch_csv=PITCH_CSV_PATH,
            notes_csv=NOTES_CSV_PATH,
        )
    with open(RENDER_SCRIPT_PATH, "w") as f:
        f.write(script + "\n")

    result = subprocess.run(["gnuplot", RENDER_SCRIPT_PATH], capture_output=True, text=True)
    if result.returncode != 0:
        print(f"[Gnuplot Error]: {result.stderr}")
        return

    if os.path.exists("/tmp/tmp.png"):
        os.replace("/tmp/tmp.png", output_path)
