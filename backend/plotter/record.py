import wave

import numpy as np

WAV_PATH = "/tmp/record.wav"


class WavRecorder:
    def __init__(self, path=WAV_PATH):
        self.path = path
        self._wave = None
        self._sample_rate = None
        self._frames = 0

    def write(self, samples, sample_rate):
        if len(samples) == 0:
            return

        if self._wave is None:
            self._wave = wave.open(self.path, "wb")
            self._wave.setnchannels(1)
            self._wave.setsampwidth(2)
            self._wave.setframerate(sample_rate)
            self._sample_rate = sample_rate
        elif sample_rate != self._sample_rate:
            raise ValueError(
                f"sample rate changed from {self._sample_rate} to {sample_rate}"
            )

        pcm = (np.clip(samples, -1.0, 1.0) * 32767).astype("<i2")
        self._wave.writeframes(pcm.tobytes())
        self._frames += len(pcm)

    def close(self):
        if self._wave is not None:
            self._wave.close()
            self._wave = None

    @property
    def duration(self):
        if self._sample_rate is None:
            return 0.0
        return self._frames / self._sample_rate

    def __enter__(self):
        return self

    def __exit__(self, exc_type, exc_value, traceback):
        self.close()
