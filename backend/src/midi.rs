use midir::{MidiInput, MidiInputConnection};
use std::sync::atomic::{AtomicU32, Ordering};
use std::sync::Mutex;

use crate::debug::DebugHandle;
use crate::event::{self, Event};
use crate::simulation;

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

    pub fn start_event_stream(
        &self,
        sender: event::EventSender,
        error_sender: event::ErrorSender,
        debug_handle: &Option<DebugHandle>,
    ) {
        if simulation::enabled() {
            simulation::start_stream(sender, error_sender, debug_handle.clone());
            return;
        }
        self.start_real_stream(sender, error_sender, debug_handle.clone());
    }

    fn start_real_stream(
        &self,
        sender: event::EventSender,
        error_sender: event::ErrorSender,
        debug_handle: Option<DebugHandle>,
    ) {
        let port_index = self.port_index.load(Ordering::Relaxed);
        if port_index == u32::MAX {
            error_sender("Not connected".to_string());
            return;
        }

        let Ok(midi_in) = MidiInput::new("nano") else {
            error_sender("Failed to create MIDI input".to_string());
            return;
        };

        let ports = midi_in.ports();
        let in_port = match ports.into_iter().nth(port_index as usize) {
            Some(p) => p,
            None => {
                error_sender("Port no longer available".to_string());
                return;
            }
        };

        let callback_sender = sender.clone();
        let callback = move |_timestamp: u64, bytes: &[u8], _data: &mut ()| {
            if let Some(event) = Event::from_midi(bytes) {
                if let Some(debugger) = &debug_handle {
                    debugger.stream_data(&format!("note:{}", event.note_name).as_bytes());
                }
                callback_sender(event);
            }
        };

        match midi_in.connect(&in_port, "nano", callback, ()) {
            Ok(conn) => {
                *self.connection.lock().unwrap() = Some(conn);
            }
            Err(e) => {
                error_sender(format!("{e}"));
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
