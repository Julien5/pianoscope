//! Microphone (and WAV file) signal source feeding a processing thread.
//!
//! The capture side reads raw audio samples from one of several sources and
//! writes them, as mono f32, into a wait-free SPSC ring buffer. A single
//! processing thread drains that buffer and computes the signal energy over a
//! fixed-length window (defaults to 250 ms). The processing thread is identical
//! regardless of the source, which is what allows replaying recorded WAV files
//! during development without a real microphone.

use std::path::{Path, PathBuf};
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::{Arc, Mutex};
use std::thread::{self, JoinHandle};
use std::time::Duration;

use cpal::traits::{DeviceTrait, HostTrait, StreamTrait};
use cpal::{SampleFormat, SizedSample};
use rtrb::{Consumer, PopError, Producer};

/// Length of the energy window in seconds.
pub const WINDOW_SECONDS: f32 = 0.25;

/// Callback invoked once per processed window with the computed energy (RMS).
pub type EnergySink = Arc<dyn Fn(f64) + Send + Sync>;

/// Callback invoked once per processed window with the raw mono samples.
pub type SampleSink = Arc<dyn Fn(&[f32]) + Send + Sync>;

/// Callback invoked when an error occurs.
pub type ErrorSink = Arc<dyn Fn(String) + Send + Sync>;

/// Where the raw audio signal comes from.
pub enum Source {
    /// A real microphone; `None` selects the system default input device.
    InputDevice(Option<usize>),
    /// A WAV file replayed at (by default) real-time cadence.
    File(FileSource),
}

/// Behaviour of the WAV-file source.
pub struct FileSource {
    pub path: PathBuf,
    /// Replay the file at real-time cadence (true) or as fast as possible (false).
    pub paced: bool,
    /// Loop the file once it reaches the end.
    pub looped: bool,
}

impl Source {
    /// A WAV file replayed at real-time cadence.
    pub fn file(path: impl Into<PathBuf>) -> Self {
        Source::File(FileSource {
            path: path.into(),
            paced: true,
            looped: false,
        })
    }
}

/// Captures a microphone (or replays a WAV file) and feeds a processing thread.
///
/// Threads spawned by [`Microphone::start`]:
/// - real source: cpal runs its own audio thread which fills the ring buffer;
/// - file source: a "nano-mic-file" thread reads the WAV and fills the ring buffer;
/// - in both cases a "nano-mic-processing" thread drains the ring buffer.
pub struct AudioStreamHandler {
    cpal_stream: Mutex<Option<cpal::Stream>>,
    stop: Mutex<Option<Arc<AtomicBool>>>,
    workers: Mutex<Vec<JoinHandle<()>>>,
    sample_rate: Mutex<u32>,
}

impl AudioStreamHandler {
    pub const fn new() -> Self {
        Self {
            cpal_stream: Mutex::new(None),
            stop: Mutex::new(None),
            workers: Mutex::new(Vec::new()),
            sample_rate: Mutex::new(0),
        }
    }

    pub fn sample_rate(&self) -> u32 {
        *self.sample_rate.lock().unwrap()
    }

    /// Start capturing from `source`, aggregating energy over `WINDOW_SECONDS`
    /// windows delivered to `energy_sink`. Returns an error if the source cannot
    /// be opened. Calling again stops any running capture first.
    pub fn start(
        &self,
        source: Source,
        energy_sink: EnergySink,
        error_sink: ErrorSink,
    ) -> Result<(), String> {
        self.start_with_samples(source, energy_sink, None, error_sink)
    }

    /// Like [`Self::start`] but additionally delivers each processed window's
    /// raw mono samples to `samples_sink`.
    pub fn start_with_samples(
        &self,
        source: Source,
        energy_sink: EnergySink,
        samples_sink: Option<SampleSink>,
        error_sink: ErrorSink,
    ) -> Result<(), String> {
        self.stop();

        let sample_rate = match &source {
            Source::InputDevice(index) => {
                let device = self.resolve_input_device(*index)?;
                let config = device.default_input_config().map_err(|e| e.to_string())?;
                config.sample_rate()
            }
            Source::File(file) => {
                let reader = hound::WavReader::open(&file.path).map_err(|e| e.to_string())?;
                reader.spec().sample_rate
            }
        };
        if sample_rate == 0 {
            return Err("invalid sample rate 0".into());
        }

        log::trace!("sample rate: {}", sample_rate);

        let window_len = (sample_rate as f32 * WINDOW_SECONDS) as usize;
        let ring_capacity = sample_rate as usize * 2;
        let (producer, consumer) = rtrb::RingBuffer::new(ring_capacity);

        *self.sample_rate.lock().unwrap() = sample_rate;

        let stop = Arc::new(AtomicBool::new(false));
        *self.stop.lock().unwrap() = Some(stop.clone());

        let processor = spawn_processing_thread(
            consumer,
            window_len,
            energy_sink,
            samples_sink,
            error_sink.clone(),
            stop.clone(),
        );
        self.workers.lock().unwrap().push(processor);

        match source {
            Source::InputDevice(index) => {
                let device = self.resolve_input_device(index)?;
                let config = device.default_input_config().map_err(|e| e.to_string())?;
                let stream = build_cpal_stream(&device, &config, producer, error_sink)
                    .map_err(|e| e.to_string())?;
                *self.cpal_stream.lock().unwrap() = Some(stream);
            }
            Source::File(file) => self.start_file_source(&file, producer, error_sink),
        }

        Ok(())
    }

    fn resolve_input_device(&self, index: Option<usize>) -> Result<cpal::Device, String> {
        let host = cpal::default_host();
        let device = match index {
            Some(i) => {
                let devices = host.input_devices().map_err(|e| e.to_string())?;
                devices
                    .into_iter()
                    .nth(i)
                    .ok_or_else(|| format!("no input device at index {i}"))?
            }
            None => host
                .default_input_device()
                .ok_or("no default input device")?,
        };
        Ok(device)
    }

    fn start_file_source(&self, file: &FileSource, producer: Producer<f32>, error_sink: ErrorSink) {
        let path = file.path.clone();
        let paced = file.paced;
        let looped = file.looped;
        let stop = self.stop.lock().unwrap().clone().unwrap();
        let worker = spawn_file_reader(
            path,
            paced,
            looped,
            self.sample_rate(),
            producer,
            stop,
            error_sink,
        );
        self.workers.lock().unwrap().push(worker);
    }

    /// Stop capture: signal all threads, stop the cpal stream, and join workers.
    pub fn stop(&self) {
        if let Some(stop) = self.stop.lock().unwrap().take() {
            stop.store(true, Ordering::Relaxed);
        }
        if let Some(stream) = self.cpal_stream.lock().unwrap().take() {
            // Dropping the stream stops the cpal audio thread, releasing the producer.
            drop(stream);
        }
        for worker in self.workers.lock().unwrap().drain(..) {
            let _ = worker.join();
        }
    }
}

impl Default for AudioStreamHandler {
    fn default() -> Self {
        Self::new()
    }
}

impl Drop for AudioStreamHandler {
    fn drop(&mut self) {
        self.stop();
    }
}

/// Builds a cpal input stream whose RT callback downsamples interleaved samples
/// of any supported format into mono f32 for `producer`.
fn build_cpal_stream(
    device: &cpal::Device,
    config: &cpal::SupportedStreamConfig,
    mut producer: Producer<f32>,
    error_sink: ErrorSink,
) -> Result<cpal::Stream, cpal::Error> {
    let channels = config.channels();
    let err_fn = {
        let error_sink = error_sink.clone();
        move |err: cpal::Error| error_sink(format!("mic stream error: {err}"))
    };
    let data_fn = move |data: &cpal::Data, _: &cpal::InputCallbackInfo| {
        push_mono(data, channels, &mut producer);
    };
    let stream = device.build_input_stream_raw(
        config.config(),
        config.sample_format(),
        data_fn,
        err_fn,
        None,
    )?;
    stream.play()?;
    Ok(stream)
}

/// Converts the filled `/`Data/` input buffer to mono f32 and pushes it into `producer`.
/// This runs on the real-time cpal callback thread: it must not block, allocate,
/// or log. If the ring buffer is full, samples are dropped.
fn push_mono(data: &cpal::Data, channels: u16, producer: &mut Producer<f32>) {
    match data.sample_format() {
        SampleFormat::F32 => push_typed::<f32>(data, channels, producer),
        SampleFormat::I8 => push_typed::<i8>(data, channels, producer),
        SampleFormat::U8 => push_typed::<u8>(data, channels, producer),
        SampleFormat::I16 => push_typed::<i16>(data, channels, producer),
        SampleFormat::U16 => push_typed::<u16>(data, channels, producer),
        SampleFormat::I32 => push_typed::<i32>(data, channels, producer),
        SampleFormat::U32 => push_typed::<u32>(data, channels, producer),
        SampleFormat::I64 => push_typed::<i64>(data, channels, producer),
        SampleFormat::F64 => push_typed::<f64>(data, channels, producer),
        _ => {}
    }
}

fn push_typed<T>(data: &cpal::Data, channels: u16, producer: &mut Producer<f32>)
where
    T: SizedSample,
    f32: cpal::FromSample<T>,
{
    let Some(sample) = data.as_slice::<T>() else {
        return;
    };
    let ch = channels as usize;
    for frame in sample.chunks_exact(ch) {
        let sum: f32 = frame.iter().map(|&s| s.to_sample::<f32>()).sum();
        let _ = producer.push(sum / ch as f32);
    }
}

/// Spawns the processing thread.
///
/// Reads mono samples from `consumer`, accumulates a window of `window_len`
/// samples, and emits the RMS energy via `energy_sink` once the window is full.
/// Exits when explicitly stopped, or when the producer is dropped (e.g. the file
/// source reached EOF), flushing any partially-filled final window.
fn spawn_processing_thread(
    mut consumer: Consumer<f32>,
    window_len: usize,
    energy_sink: EnergySink,
    samples_sink: Option<SampleSink>,
    error_sink: ErrorSink,
    stop: Arc<AtomicBool>,
) -> JoinHandle<()> {
    let spawn_err = error_sink.clone();
    thread::Builder::new()
        .name("nano-mic-processing".into())
        .spawn(move || {
            let mut buf: Vec<f32> = Vec::with_capacity(window_len);
            loop {
                match consumer.pop() {
                    Ok(sample) => buf.push(sample),
                    Err(PopError::Empty) => {
                        if consumer.is_abandoned() || stop.load(Ordering::Relaxed) {
                            break;
                        }
                        thread::sleep(Duration::from_micros(200));
                    }
                }
                if buf.len() >= window_len {
                    if let Some(sink) = &samples_sink {
                        sink(&buf);
                    }
                    energy_sink(energy(&buf));
                    buf.clear();
                }
            }
            if !buf.is_empty() {
                if let Some(sink) = &samples_sink {
                    sink(&buf);
                }
                energy_sink(energy(&buf));
            }
        })
        .unwrap_or_else(|e| {
            spawn_err(format!("failed to spawn processing thread: {e}"));
            // A failed spawn must still give us a joinable handle.
            thread::Builder::new().spawn(|| {}).unwrap()
        })
}

/// Reads a WAV file, downmixes it to mono f32, and feeds `producer` — mimicking
/// the cpal audio thread by pacing at the real sample rate.
fn spawn_file_reader(
    path: PathBuf,
    paced: bool,
    looped: bool,
    sample_rate: u32,
    mut producer: Producer<f32>,
    stop: Arc<AtomicBool>,
    error_sink: ErrorSink,
) -> JoinHandle<()> {
    let spawn_err = error_sink.clone();
    thread::Builder::new()
        .name("nano-mic-file".into())
        .spawn(move || {
            const BATCH: usize = 1024;
            loop {
                let samples = match read_mono_f32(&path) {
                    Ok(s) => s,
                    Err(e) => {
                        error_sink(format!("failed to read WAV file {}: {e}", path.display()));
                        return;
                    }
                };
                let mut batch: Vec<f32> = Vec::with_capacity(BATCH);
                for &s in &samples {
                    if stop.load(Ordering::Relaxed) {
                        return;
                    }
                    batch.push(s);
                    if batch.len() == BATCH {
                        for &v in &batch {
                            let _ = producer.push(v);
                        }
                        batch.clear();
                        if paced {
                            thread::sleep(Duration::from_secs_f64(
                                BATCH as f64 / sample_rate as f64,
                            ));
                        }
                    }
                }
                if !batch.is_empty() {
                    for &v in &batch {
                        let _ = producer.push(v);
                    }
                }
                if !looped {
                    break;
                }
            }
            // Producer dropped here → the processing thread sees `is_abandoned()`.
        })
        .unwrap_or_else(|e| {
            spawn_err(format!("failed to spawn file reader thread: {e}"));
            thread::Builder::new().spawn(|| {}).unwrap()
        })
}

/// Reads a WAV file into a mono f32 buffer in the normalized [-1.0, 1.0] range.
fn read_mono_f32(path: &Path) -> Result<Vec<f32>, String> {
    let mut reader = hound::WavReader::open(path).map_err(|e| e.to_string())?;
    let spec = reader.spec();
    let channels = spec.channels.max(1) as usize;
    let norm = normalization(&spec);
    let mut out = Vec::new();
    match spec.sample_format {
        hound::SampleFormat::Int => {
            for frame in reader.samples::<i32>() {
                let frame = frame.map_err(|e| e.to_string())?;
                out.push(norm * frame as f32);
            }
        }
        hound::SampleFormat::Float => {
            for frame in reader.samples::<f32>() {
                let frame = frame.map_err(|e| e.to_string())?;
                out.push(frame);
            }
        }
    }
    if channels > 1 {
        // downmix interleaved frames
        let ch = channels;
        let mono: Vec<f32> = out
            .chunks_exact(ch)
            .map(|fr| fr.iter().sum::<f32>() / ch as f32)
            .collect();
        Ok(mono)
    } else {
        Ok(out)
    }
}

/// Scale factor to bring WAV samples into [-1.0, 1.0] so energy is comparable to
/// the (already normalized) cpal f32 capture.
fn normalization(spec: &hound::WavSpec) -> f32 {
    if spec.sample_format == hound::SampleFormat::Int {
        1.0 / (2u32.pow(spec.bits_per_sample as u32 - 1) as f32)
    } else {
        1.0
    }
}

/// RMS energy of a window, in the [-1..1] sample unit.
pub fn energy(samples: &[f32]) -> f64 {
    if samples.is_empty() {
        return 0.0;
    }
    //samples.iter().map(|x| x.abs()).fold(0f32 / 0f32, f32::max) as f64
    let sum_sq: f64 = samples.iter().map(|&s| (s as f64) * (s as f64)).sum();
    (sum_sq / samples.len() as f64).sqrt()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn normalization_of_int_and_float() {
        let int_spec = hound::WavSpec {
            channels: 1,
            sample_rate: 44100,
            bits_per_sample: 16,
            sample_format: hound::SampleFormat::Int,
        };
        assert!((normalization(&int_spec) - 1.0 / 32768.0).abs() < f32::EPSILON);

        let float_spec = hound::WavSpec {
            channels: 1,
            sample_rate: 44100,
            bits_per_sample: 32,
            sample_format: hound::SampleFormat::Float,
        };
        assert_eq!(normalization(&float_spec), 1.0);
    }
}
