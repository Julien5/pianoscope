import base64
import collections
import json
import time

import numpy as np
import zmq

from plot import (
    MIN_PLOT_INTERVAL,
    render_plot,
    trim_buffer,
)


def decode_b64(block):
    raw_bytes = base64.b64decode(block)
    return np.frombuffer(raw_bytes, dtype="<f8")

def message_midi(data):
    name=data["note_name"];
    status=data["status"];
    return f"{name}:{status}"

class PitchDetector:
    def __init__(self, data):
        self.threshold = data["threshold"]
        self.level_min = data["level_min"]
        self.level_max = data["level_max"]
        self.current = data["current"]
        self.energy = data["energy"]
        self.sample_rate = data["sample_rate"]

    def __str__(self):
        return f"energy={self.energy:.3f} thr={self.threshold} cur={self.current!r} rate={self.sample_rate}"


class AudioDatablock:
    def __init__(self, data):
        self.audio_base64 = data["audio_base64"]
        self.pitch_detector = PitchDetector(data["pitch_stats"])

    @property
    def sample_rate(self):
        return self.pitch_detector.sample_rate

    @property
    def num_samples(self):
        return len(base64.b64decode(self.audio_base64)) // 8

    def samples(self, step=1):
        raw = decode_b64(self.audio_base64)
        return raw if step == 1 else raw[::step]

    def __str__(self):
        return f"n={self.num_samples} {self.pitch_detector}"


class AudioDebugPacket:
    def __init__(self, data):
        self.audio = AudioDatablock(data["audio"])

    @property
    def sample_rate(self):
        return self.audio.sample_rate

    def __str__(self):
        return f"audio({self.audio})" 

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
                    if "audio" in data:
                        packet = AudioDebugPacket(data)
                        buffer.append(packet)
                        trim_buffer(buffer)
                        dirty = True
                        msg = str(packet)
                    elif "event" in data:
                        msg = message_midi(data["event"]);
                    elapsed = time.perf_counter() - t0
                    print(f"|{elapsed:5.1f}| {msg}")    
                except KeyError as e:
                    print("key error:",e);

        now = time.perf_counter()
        if dirty and now - last_plot >= MIN_PLOT_INTERVAL:
            render_plot(buffer)
            last_plot = now
            dirty = False


def main():
    context = zmq.Context()
    socket = context.socket(zmq.SUB)
    #ip="192.168.1.100";
    ip="127.0.0.1";
    print("connect to",ip)
    socket.connect(f"tcp://{ip:s}:9000")

    # CRITICAL: Subscribe to ALL topics (empty string prefix)
    socket.setsockopt(zmq.SUBSCRIBE, b"")
    # Generous queue so nothing is dropped while gnuplot renders.
    socket.setsockopt(zmq.RCVHWM, 50_000)

    buffer = collections.deque()
    run(socket, buffer)


if __name__ == "__main__":
    main()
