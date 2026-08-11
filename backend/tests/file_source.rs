//! Integration tests for the WAV-file signal source feeding the processing thread.

use std::path::Path;
use std::sync::mpsc;
use std::sync::Arc;

use backend::microphone::hardware::AudioStreamHandler;
use backend::microphone::hardware::{EnergySink, FileSource, Source};

use hound::{SampleFormat, WavSpec, WavWriter};

/// Writes `seconds` of a mono 16-bit sine at `amplitude` (0..=1.0) into `path`.
fn write_sine_wav(path: &Path, freq: f32, amplitude: f32, seconds: usize) {
    let spec = WavSpec {
        channels: 1,
        sample_rate: 44_100,
        bits_per_sample: 16,
        sample_format: SampleFormat::Int,
    };
    let mut writer = WavWriter::create(path, spec).expect("create wav");
    let amp_i16 = (amplitude * (1 << 15) as f32) as i16;
    for i in 0..spec.sample_rate as usize * seconds {
        let t = i as f32 / spec.sample_rate as f32;
        let v = (amp_i16 as f32 * (2.0 * std::f32::consts::PI * freq * t).sin()) as i16;
        writer.write_sample(v).expect("write sample");
    }
    writer.finalize().expect("finalize");
}

#[test]
fn file_source_energy_matches_sine_amplitude() {
    let path = std::env::temp_dir().join(format!(
        "pianoscope_file_source_{}_{}.wav",
        std::process::id(),
        std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .unwrap()
            .as_nanos()
    ));
    write_sine_wav(&path, 440.0, 0.5, 3);

    let mic = AudioStreamHandler::new();
    let (tx, rx) = mpsc::channel::<f64>();
    let energy_sink: EnergySink = Arc::new(move |e| {
        let _ = tx.send(e);
    });
    let error_sink = Arc::new(|msg: String| panic!("unexpected error: {msg}"));

    let source = Source::File(FileSource {
        path: path.clone(),
        paced: false,
        looped: true,
    });
    mic.start(source, energy_sink, error_sink).expect("start");

    let energies: Vec<f64> = rx.iter().take(6).collect();
    mic.stop();
    let _ = std::fs::remove_file(&path);

    assert_eq!(energies.len(), 6, "expected 6 windows");
    let expected = 0.5 / std::f64::consts::SQRT_2;
    for (i, e) in energies.iter().enumerate() {
        assert!(
            (e - expected).abs() < 1e-2,
            "window {i}: energy {e} != expected {expected}"
        );
    }
}
