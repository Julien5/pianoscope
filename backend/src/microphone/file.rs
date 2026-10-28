use std::{
    path::Path,
    sync::{
        atomic::{AtomicBool, Ordering},
        Arc,
    },
    thread::{self, JoinHandle},
    time::Duration,
};

use rtrb::{Producer, PushError};

use crate::microphone::processor::{BlockProcessorFactory, BlockProcessorParameters};
use crate::microphone::{consumer::Consumer, WavfileSpec};
use crate::{event, microphone::consumer::WINDOW_SECONDS};

pub struct ActiveWavFile {
    file_reader: Option<JoinHandle<()>>,
    consumer: Consumer,
}

fn normalization(spec: &hound::WavSpec) -> f32 {
    if spec.sample_format == hound::SampleFormat::Int {
        1.0 / (2u32.pow(spec.bits_per_sample as u32 - 1) as f32)
    } else {
        1.0
    }
}

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

fn read_wav_sample_rate(path: &Path) -> Result<u32, String> {
    let reader = hound::WavReader::open(path)
        .map_err(|e| format!("failed to open WAV file {}: {e}", path.display()))?;
    let sample_rate = reader.spec().sample_rate;
    if sample_rate == 0 {
        return Err(format!("invalid sample rate 0 in {}", path.display()));
    }
    Ok(sample_rate)
}

/// Pushes one sample into `producer`.
///
/// With `backpressure`, a full ring buffer is waited on instead of dropping the
/// sample, so an offline (unpaced) file source processes every sample. Without
/// it, the sample is dropped to keep a real-time source on schedule. Returns
/// `false` when the stream was stopped or the consumer is gone.
fn push_sample(
    producer: &mut Producer<f32>,
    mut sample: f32,
    stop: &AtomicBool,
    backpressure: bool,
) -> bool {
    loop {
        match producer.push(sample) {
            Ok(()) => return true,
            Err(PushError::Full(returned)) => {
                if !backpressure {
                    return true;
                }
                if stop.load(Ordering::Relaxed) || producer.is_abandoned() {
                    return false;
                }
                sample = returned;
                thread::yield_now();
            }
        }
    }
}

fn spawn_wav_reader(
    spec: &WavfileSpec,
    stop: Arc<AtomicBool>,
    mut producer: Producer<f32>,
    sample_rate: u32,
    error: event::ErrorSender,
) -> Result<JoinHandle<()>, String> {
    let path = spec.path.clone();
    let paced = spec.paced;
    let looped = spec.looped;
    thread::Builder::new()
        .name("nano-mic-file".into())
        .spawn(move || {
            const BATCH: usize = 1024;
            loop {
                let samples = match read_mono_f32(&path) {
                    Ok(samples) => samples,
                    Err(e) => {
                        error(format!("failed to read WAV file {}: {e}", path.display()));
                        return;
                    }
                };
                log::trace!("file has {} samples", samples.len());
                let mut batch: Vec<f32> = Vec::with_capacity(BATCH);
                for &sample in &samples {
                    if stop.load(Ordering::Relaxed) {
                        return;
                    }
                    batch.push(sample);
                    if batch.len() == BATCH {
                        for &value in &batch {
                            if !push_sample(&mut producer, value, &stop, !paced) {
                                return;
                            }
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
                    for &value in &batch {
                        if !push_sample(&mut producer, value, &stop, !paced) {
                            return;
                        }
                    }
                }
                if !looped {
                    break;
                }
            }
        })
        .map_err(|e| format!("failed to spawn WAV reader thread: {e}"))
}

impl ActiveWavFile {
    pub fn new(
        spec: &WavfileSpec,
        factory: BlockProcessorFactory,
        error: event::ErrorSender,
    ) -> Result<ActiveWavFile, String> {
        let sample_rate = read_wav_sample_rate(&spec.path)?;
        let window_len = ((sample_rate as f32 * WINDOW_SECONDS) as usize).max(1);
        let (producer, consumer) = Consumer::spawn(
            factory,
            BlockProcessorParameters {
                sample_rate,
                window_len,
            },
        )?;
        let stop = consumer.stop_token();
        let file_reader = spawn_wav_reader(&spec, stop, producer, sample_rate, error)?;
        Ok(ActiveWavFile {
            file_reader: Some(file_reader),
            consumer,
        })
    }

    pub fn is_finished(&self) -> bool {
        self.consumer.is_finished()
            && self
                .file_reader
                .as_ref()
                .is_none_or(|reader| reader.is_finished())
    }
}

impl Drop for ActiveWavFile {
    fn drop(&mut self) {
        self.consumer.stop_token().store(true, Ordering::Relaxed);
        if let Some(reader) = self.file_reader.take() {
            let _ = reader.join();
        }
    }
}
