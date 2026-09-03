use midir::{MidiInput, MidiInputConnection, MidiInputPort};
use std::ops::Deref;
use std::sync::Mutex;
use std::thread::JoinHandle;
mod midi_simulation;

use crate::debug::packets::EventDebugPacket;
use crate::debug::DebugHandle;
use crate::event::{self, MidiEvent};

#[derive(Clone)]
pub struct MidiPort {
    pub name: String,
    pub id: String,
}

impl MidiPort {
    pub fn from_midir(name: &String, p: &MidiInputPort) -> Self {
        Self {
            name: name.clone(),
            id: p.id(),
        }
    }
}

enum Input {
    None,
    Sim(JoinHandle<()>),
    // Stored for its RAII side effect: dropping the connection stops the midir thread.
    #[allow(dead_code)]
    Device(MidiInputConnection<()>),
}

pub struct Midi {
    port: MidiPort,
    input: Mutex<Input>,
}

impl Midi {
    pub fn new(port: &MidiPort) -> Self {
        Self {
            port: port.clone(),
            input: Mutex::new(Input::None),
        }
    }

    pub fn connect(&self) -> Result<MidiPort, String> {
        // no op
        Ok(self.port.clone())
    }

    pub fn start_event_stream(
        &self,
        event_sender: event::EventSender,
        error_sender: event::ErrorSender,
        debug_handle: &Option<DebugHandle>,
    ) {
        if crate::simulation::enabled() {
            let handle =
                midi_simulation::start_stream(event_sender, error_sender, debug_handle.clone());
            *self.input.lock().unwrap() = Input::Sim(handle);
            return;
        }
        self.start_real_stream(event_sender, error_sender, debug_handle.clone());
    }

    pub fn stream_done(&self) -> bool {
        match self.input.lock().unwrap().deref() {
            Input::Sim(handle) => handle.is_finished(),
            Input::Device(_) => false,
            Input::None => false,
        }
    }

    fn start_real_stream(
        &self,
        event_sender: event::EventSender,
        error_sender: event::ErrorSender,
        debug_handle: Option<DebugHandle>,
    ) {
        let wanted_port = self.port.clone();
        if wanted_port.name.is_empty() {
            error_sender(format!("port name is empty"));
            return;
        }

        let Ok(midi_in) = MidiInput::new("nano") else {
            error_sender(format!("could not create midi input"));
            return;
        };

        let in_port = midi_in
            .ports()
            .into_iter()
            .find(|port| port.id() == wanted_port.id);

        if in_port.is_none() {
            error_sender(format!(
                "could not find midi port {} (disconnected)",
                wanted_port.name
            ));
            return;
        }

        let in_port = in_port.unwrap();

        let callback_sender = event_sender.clone();
        let callback = move |_timestamp: u64, bytes: &[u8], _data: &mut ()| {
            if let Some(event) = MidiEvent::from_midi(bytes) {
                if let Some(debugger) = &debug_handle {
                    debugger
                        .stream_data(&EventDebugPacket::from_event(&event).as_json().as_bytes());
                }
                callback_sender(event);
            }
        };

        match midi_in.connect(&in_port, "nano", callback, ()) {
            Ok(conn) => {
                *self.input.lock().unwrap() = Input::Device(conn);
            }
            Err(e) => {
                error_sender(format!("{e}"));
            }
        }
    }

    pub fn disconnect(&self) {
        if crate::simulation::enabled() {
            midi_simulation::disconnect_midi();
        }
        *self.input.lock().unwrap() = Input::None;
    }
}

pub fn list_midi_ports() -> Vec<MidiPort> {
    if crate::simulation::enabled() {
        return vec![MidiPort {
            name: "Simulated MIDI Device".to_string(),
            id: "Simulated MIDI Device ID".to_string(),
        }];
    }
    if let Ok(midi_in) = MidiInput::new("nano-list") {
        return midi_in
            .ports()
            .iter()
            .filter_map(|p| {
                if let Ok(name) = midi_in.port_name(p) {
                    Some(MidiPort::from_midir(&name, &p))
                } else {
                    None
                }
            })
            .collect();
    } else {
        return vec![];
    };
}
