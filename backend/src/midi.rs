use midir::{MidiInput, MidiInputConnection};
use std::sync::atomic::{AtomicU32, Ordering};
use std::sync::{Arc, Mutex};

use crate::simulation;

const NOTE_NAMES: &[&str] = &[
    "C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B",
];

pub type EventSender = Arc<dyn Fn(String) + Send + Sync>;

pub struct Midi {
    port_index: AtomicU32,
    connection: Mutex<Option<MidiInputConnection<()>>>,
}

impl Midi {
    pub const fn new() -> Self {
        Self {
            port_index: AtomicU32::new(u32::MAX),
            connection: Mutex::new(None),
        }
    }

    pub fn connect(&self, port_index: u32) -> Result<String, String> {
        let ports = list_midi_ports();
        let port_name = ports
            .get(port_index as usize)
            .ok_or_else(|| "Invalid port index".to_string())?
            .clone();

        if !simulation::enabled() {
            let midi_in = MidiInput::new("nano").map_err(|e| e.to_string())?;
            let _ports = midi_in.ports();
            let _in_port = _ports
                .get(port_index as usize)
                .ok_or_else(|| "Port no longer available".to_string())?;
        }

        self.port_index.store(port_index, Ordering::Relaxed);
        Ok(port_name)
    }

    pub fn start_event_stream(&self, sender: EventSender) {
        if simulation::enabled() {
            simulation::start_stream(sender);
            return;
        }
        self.start_real_stream(sender);
    }

    fn start_real_stream(&self, sender: EventSender) {
        let port_index = self.port_index.load(Ordering::Relaxed);
        if port_index == u32::MAX {
            sender("ERROR: Not connected".to_string());
            return;
        }

        let Ok(midi_in) = MidiInput::new("nano") else {
            sender("ERROR: Failed to create MIDI input".to_string());
            return;
        };

        let ports = midi_in.ports();
        let in_port = match ports.into_iter().nth(port_index as usize) {
            Some(p) => p,
            None => {
                sender("ERROR: Port no longer available".to_string());
                return;
            }
        };

        let callback_sender = sender.clone();
        let callback = move |_timestamp: u64, bytes: &[u8], _data: &mut ()| {
            if let Some(msg) = format_midi_event(bytes) {
                callback_sender(msg);
            }
        };

        match midi_in.connect(&in_port, "nano", callback, ()) {
            Ok(conn) => {
                *self.connection.lock().unwrap() = Some(conn);
                sender("CONNECTED".to_string());
            }
            Err(e) => {
                sender(format!("ERROR: {e}"));
            }
        }
    }

    pub fn disconnect(&self) {
        if simulation::enabled() {
            simulation::disconnect_midi();
        }
        *self.connection.lock().unwrap() = None;
    }
}

pub fn format_midi_event(bytes: &[u8]) -> Option<String> {
    if bytes.len() < 3 {
        return None;
    }
    let status = bytes[0] & 0xF0;
    let note = bytes[1];
    let velocity = bytes[2];

    let event_type = if status == 0x90 && velocity > 0 {
        "NOTE_ON"
    } else {
        "NOTE_OFF"
    };

    let raw = bytes
        .iter()
        .map(|b| format!("{b:02X}"))
        .collect::<Vec<_>>()
        .join(" ");

    let note_idx = (note % 12) as usize;
    let note_name = NOTE_NAMES[note_idx];
    let octave = (note / 12) as i32 - 1;
    let name = format!("{note_name}{octave}");

    Some(format!("{event_type} {raw} {name}"))
}

pub fn list_midi_ports() -> Vec<String> {
    if simulation::enabled() {
        return vec!["Simulated MIDI Device".to_string()];
    }
    if let Ok(midi_in) = MidiInput::new("nano-list") {
        return midi_in
            .ports()
            .iter()
            .filter_map(|p| midi_in.port_name(p).ok())
            .collect();
    } else {
        return vec![];
    };
}
