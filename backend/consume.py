import base64
import collections
import csv
import json
import os
import subprocess
import time

import numpy as np
import zmq

INPUT_SAMPLE_FREQ = 48_000
DOWNSAMPLE_FACTOR = 16
SAMPLE_FREQ = INPUT_SAMPLE_FREQ / DOWNSAMPLE_FACTOR
WINDOW_SIZE = int(INPUT_SAMPLE_FREQ * 5 / DOWNSAMPLE_FACTOR)
WINDOW_SECONDS = WINDOW_SIZE / SAMPLE_FREQ
MIN_PLOT_INTERVAL = 0.5
DATA_CSV_PATH = "/tmp/plot.csv"
PLOT_PNG_PATH = "/tmp/plot.png"


def save_data_csv(buffer_data, path=DATA_CSV_PATH):
    if not buffer_data:
        return

    tmp_path = "/tmp/tmp_data.csv"
    with open(tmp_path, "w", newline="", encoding="utf-8") as f:
        writer = csv.writer(f)
        writer.writerow(["sample_index", "value"])
        for index, value in enumerate(buffer_data):
            writer.writerow([index, value])

    os.replace(tmp_path, path)


def decode_b64(block):
    raw_bytes = base64.b64decode(block)
    return np.frombuffer(raw_bytes, dtype="<f8")


def render_plot_pipe(buffer_data, output_path=PLOT_PNG_PATH):
    if len(buffer_data) == 0:
        return

    count = len(buffer_data)

    gnuplot_script = f"""
    set terminal pngcairo size 1200,600
    set output '/tmp/tmp.png'
    set title 'Last {count} Samples'
    set xlabel 't (s)'
    set ylabel 'y'
    set grid

    # set autoscale x
    # set autoscale y
    set xrange [0:{WINDOW_SECONDS}]
    set yrange [-0.1:0.1]

    plot '-' using 1:2 with lines title 'Signal'
    """

    for index, value in enumerate(buffer_data):
        t = index / SAMPLE_FREQ
        gnuplot_script += f"{t:.6f} {value}\n"
    gnuplot_script += "e\n"

    process = subprocess.Popen(
        ["gnuplot"],
        stdin=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )

    _stdout, stderr = process.communicate(input=gnuplot_script.encode("utf-8"))

    if process.returncode != 0:
        print(f"[Gnuplot Error]: {stderr.decode('utf-8', errors='replace')}")
        return

    if os.path.exists("/tmp/tmp.png"):
        os.replace("/tmp/tmp.png", output_path)

def message_audio(x):
    energy = np.sum(np.abs(x) ** 2)
    return f"|{len(x):3d}| => E={energy:6.3f}";

def message_midi(data):
    name=data["note_name"];
    status=data["status"];
    return f"{name}:{status}"
                    
def run(socket, buffer):
    t0 = time.perf_counter()
    last_plot = 0.0
    dirty = False
    print("Connected to port 9000. Waiting for packets...")

    while True:
        if socket.poll(timeout=500):
            while True:
                try:
                    raw_bytes = socket.recv(zmq.NOBLOCK)
                except zmq.ZMQError:
                    break
                try:
                    data = json.loads(raw_bytes)
                    msg = "";
                    if "base64" in data:
                        x = decode_b64(data["base64"])
                        x = x[::DOWNSAMPLE_FACTOR]
                        buffer.extend(x)
                        dirty = True
                        msg=message_audio(x);
                    else:
                        msg=message_midi(data);
                    elapsed = time.perf_counter() - t0
                    print(f"|{elapsed:5.1f}| {msg}")    
                except KeyError as e:
                    print("error:",e);

        now = time.perf_counter()
        if dirty and now - last_plot >= MIN_PLOT_INTERVAL:
            save_data_csv(buffer)
            render_plot_pipe(buffer)
            last_plot = now
            dirty = False


def main():
    context = zmq.Context()
    socket = context.socket(zmq.SUB)
    socket.connect("tcp://127.0.0.1:9000")
    # socket.connect("tcp://192.168.1.100:9000")

    # CRITICAL: Subscribe to ALL topics (empty string prefix)
    socket.setsockopt(zmq.SUBSCRIBE, b"")
    # Generous queue so nothing is dropped while gnuplot renders.
    socket.setsockopt(zmq.RCVHWM, 50_000)

    buffer = collections.deque(maxlen=WINDOW_SIZE)
    run(socket, buffer)


if __name__ == "__main__":
    main()
