use std::sync::Arc;
use std::time::Duration;

use backend::debug::DebugHandle;
use backend::event::Event;
use backend::microphone::hardware::{AudioStreamHandler, ErrorSink, SampleSink, Source};
use backend::midi::{self, Midi};

fn setup_log() {
    // println!("init logger");
    //env_logger::init();

    use std::io::Write;
    let _ = env_logger::Builder::new()
        .format(|buf, record| {
            writeln!(
                buf,
                "{} [{}] - {}",
                chrono::Local::now().format("%H:%M:%S:%f"),
                record.level(),
                record.args()
            )
        })
        .filter_level(log::LevelFilter::Trace)
        .try_init();
}

fn main_midi() {
    println!("Opening ZMQ debug server on port 9000...");
    let debug = DebugHandle::new();

    let midi = Midi::new();

    let ports = midi::list_midi_ports();
    println!("MIDI ports:");
    for (i, name) in ports.iter().enumerate() {
        println!("  [{i}] {name}");
    }
    if ports.is_empty() {
        eprintln!("No MIDI ports found. Aborting.");
        return;
    }

    let port_index = std::env::args()
        .nth(1)
        .and_then(|s| s.parse::<u32>().ok())
        .unwrap_or(0);
    match midi.connect(port_index) {
        Ok(name) => println!("Connected to MIDI port [{port_index}] {name}"),
        Err(e) => {
            eprintln!("Failed to connect to MIDI port [{port_index}]: {e}");
            return;
        }
    }

    let debug_handle: Option<DebugHandle> = Some(debug);
    let sender = Arc::new(|_event: Event| {});
    let error_sender = Arc::new(|msg: String| eprintln!("midi error: {msg}"));
    midi.start_event_stream(sender, error_sender, &debug_handle);

    println!("MIDI events will now be streamed over ZMQ. Waiting...");
    loop {
        std::thread::sleep(Duration::from_secs(1));
    }
}

fn main_audio() {
    println!("Opening ZMQ debug server on port 9000...");
    let debug = DebugHandle::new();

    let mic = AudioStreamHandler::new();
    let sample_sink: SampleSink = {
        let debug = debug.clone();
        Arc::new(move |samples: &[f32]| {
            let bytes = bytemuck::cast_slice::<f32, u8>(samples);
            debug.stream_data(bytes);
        })
    };
    let error_sink: ErrorSink = Arc::new(|msg| log::error!("mic error: {msg}"));

    match mic.start_with_samples(
        Source::InputDevice(None),
        Arc::new(|_| {}),
        Some(sample_sink),
        error_sink,
    ) {
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

fn main() {
    setup_log();
    //main_audio();
    main_midi();
}
