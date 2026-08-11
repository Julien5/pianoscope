use std::{sync::Arc, time::Duration};

use backend::{debug::DebugHandle, event::Event, midi};

pub fn main(port: u32) {
    println!("Opening ZMQ debug server on port 9000...");
    let debug = DebugHandle::new();

    let midi = midi::Midi::new();

    let ports = midi::list_midi_ports();
    println!("MIDI ports:");
    for (i, name) in ports.iter().enumerate() {
        println!("  [{i}] {name}");
    }
    if ports.is_empty() {
        eprintln!("No MIDI ports found. Aborting.");
        return;
    }

    match midi.connect(port) {
        Ok(name) => println!("Connected to MIDI port [{port}] {name}"),
        Err(e) => {
            eprintln!("Failed to connect to MIDI port [{port}]: {e}");
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
