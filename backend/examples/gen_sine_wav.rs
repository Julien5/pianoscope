//! Generates a synthetic sine-wave WAV file so the microphone signal pipeline can
//! be exercised without any physical microphone.
//!
//! Usage: `cargo run --example gen_sine_wav -- [output.wav]`

use hound::{SampleFormat, WavSpec, WavWriter};

fn main() {
    env_logger::init();

    let out = std::env::args().nth(1).unwrap_or_else(|| "sine.wav".to_string());
    let spec = WavSpec {
        channels: 1,
        sample_rate: 44_100,
        bits_per_sample: 16,
        sample_format: SampleFormat::Int,
    };
    let mut writer = WavWriter::create(&out, spec).expect("create wav");
    let freq: f32 = 440.0;
    let amplitude: f32 = 0.5 * (1 << 15) as f32; // half of full-scale 16-bit
    let seconds: usize = 3;
    let total = spec.sample_rate as usize * seconds;
    for i in 0..total {
        let t = i as f32 / spec.sample_rate as f32;
        let v = (amplitude * (2.0 * std::f32::consts::PI * freq * t).sin()) as i16;
        writer.write_sample(v).expect("write sample");
    }
    writer.finalize().expect("finalize");
    log::info!(
        "wrote {out}: {seconds}s mono 16-bit {freq} Hz sine at full scale"
    );
}