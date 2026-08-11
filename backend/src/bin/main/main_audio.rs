use std::{path::PathBuf, sync::Arc, time::Duration};

use backend::{
    debug::DebugHandle,
    event::AudioDatablock,
    microphone::hardware::{
        AudioStreamHandler, ErrorSink, FileSource, SampleSink, Source as AudioSource,
    },
};

pub fn wavfile(filename: String) -> AudioSource {
    let source = FileSource {
        path: PathBuf::from(filename),
        paced: true,
        looped: true,
    };
    AudioSource::File(source)
}

pub fn microphone() -> AudioSource {
    AudioSource::InputDevice(None)
}

pub fn main(filename: Option<String>) {
    println!("Opening ZMQ debug server on port 9000...");
    let debug = DebugHandle::new();

    let mic = AudioStreamHandler::new();
    let sample_sink: SampleSink = {
        let debug = debug.clone();
        Arc::new(move |samples: &[f32]| {
            log::trace!("sending {} bytes", samples.len());
            debug.stream_data(AudioDatablock::from_samples(samples).as_json().as_bytes());
        })
    };
    let error_sink: ErrorSink = Arc::new(|msg| log::error!("mic error: {msg}"));

    let source = if let Some(path) = filename {
        wavfile(path)
    } else {
        microphone()
    };

    match mic.start_with_samples(source, Arc::new(|_| {}), Some(sample_sink), error_sink) {
        Ok(()) => println!("Capturing from default microphone, streaming audio over ZMQ."),
        Err(e) => {
            println!("Failed to start microphone capture: {e}");
            return;
        }
    }

    loop {
        std::thread::sleep(Duration::from_secs(1));
    }
}
