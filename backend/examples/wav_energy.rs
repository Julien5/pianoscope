//! Logs the signal energy of a microphone (or a WAV file) over 250 ms windows.
//!
//! Usage:
//!   cargo run --example wav_energy                 # real microphone
//!   cargo run --example wav_energy -- --file x.wav  # replay a WAV file

use std::path::PathBuf;
use std::sync::Arc;
use std::time::Duration;

use backend::microphone::hardware::{
    AudioStreamHandler, EnergySink, ErrorSink, Source, WINDOW_SECONDS,
};

fn main() {
    env_logger::Builder::from_env(env_logger::Env::default().default_filter_or("info")).init();

    let mut path: Option<PathBuf> = None;
    let mut args = std::env::args().skip(1);
    while let Some(arg) = args.next() {
        match arg.as_str() {
            "--file" => path = args.next().map(PathBuf::from),
            other => {
                eprintln!("unknown argument: {other}");
                std::process::exit(2);
            }
        }
    }

    let source = match path {
        Some(p) => Source::file(p),
        None => Source::InputDevice(None),
    };

    let mic = AudioStreamHandler::new();
    let energy_sink: EnergySink = Arc::new(|e| {
        log::info!("energy ({} ms): {e:.6}", WINDOW_SECONDS * 1000.0);
    });
    let error_sink: ErrorSink = Arc::new(|msg| log::error!("mic error: {msg}"));

    if let Err(e) = mic.start(source, energy_sink, error_sink) {
        log::error!("failed to start capture: {e}");
        std::process::exit(1);
    }

    std::thread::sleep(Duration::from_secs(10));
    mic.stop();
    log::info!("done");
}
