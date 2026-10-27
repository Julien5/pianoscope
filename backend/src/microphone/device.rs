use cpal::traits::{DeviceTrait, HostTrait, StreamTrait};
use cpal::{SampleFormat, SizedSample};
use rtrb::Producer;

use crate::event;
use crate::microphone::consumer::{Consumer, WINDOW_SECONDS};
use crate::microphone::processor::{BlockProcessorFactory, BlockProcessorParameters};

pub struct ActiveDevice {
    stream: cpal::Stream,
    consumer: Consumer,
}

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

fn build_device_stream(
    device: &cpal::Device,
    config: &cpal::SupportedStreamConfig,
    mut producer: Producer<f32>,
    error: event::ErrorSender,
) -> Result<cpal::Stream, String> {
    let channels = config.channels();
    let data_fn = move |data: &cpal::Data, _: &cpal::InputCallbackInfo| {
        push_mono(data, channels, &mut producer);
    };
    let error_sink = error.clone();
    let err_fn = move |err: cpal::Error| {
        error_sink(format!("microphone stream error: {err}"));
    };
    let stream = device
        .build_input_stream_raw(
            config.config(),
            config.sample_format(),
            data_fn,
            err_fn,
            None,
        )
        .map_err(|e| e.to_string())?;
    stream.play().map_err(|e| e.to_string())?;
    Ok(stream)
}

fn resolve_device() -> Result<cpal::Device, String> {
    let host = cpal::default_host();
    host.default_input_device()
        .ok_or_else(|| "no default input device".to_string())
}

impl ActiveDevice {
    pub fn new(factory: BlockProcessorFactory, error: event::ErrorSender) -> Result<Self, String> {
        let device = resolve_device()?;
        let config = device.default_input_config().map_err(|e| e.to_string())?;
        let sample_rate = config.sample_rate();
        if sample_rate == 0 {
            return Err("invalid microphone sample rate 0".to_string());
        }
        let window_len = ((sample_rate as f32 * WINDOW_SECONDS) as usize).max(1);
        let parameters = BlockProcessorParameters {
            sample_rate,
            window_len,
        };
        let (producer, consumer) = Consumer::spawn(factory, parameters)?;
        let stream = build_device_stream(&device, &config, producer, error)?;
        Ok(ActiveDevice { stream, consumer })
    }

    pub fn is_finished(&self) -> bool {
        self.consumer.is_finished()
    }
}
