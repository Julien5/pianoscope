use midir::{MidiInput, MidiInputConnection, MidiInputPort};
use std::ops::Deref;
use std::sync::Mutex;
use std::thread::JoinHandle;
mod midi_simulation;

use crate::debug::packets::EventDebugPacket;
use crate::debug::DebugServerHandle;
use crate::event::{self, MidiEvent};
use crate::simulation;

#[derive(Clone)]
pub struct MidiPort {
    pub name: String,
    pub id: String,
}

static SIMULATEDMIDI: &str = &"Simulated MIDI Device";

impl MidiPort {
    pub fn from_midir(name: &String, p: &MidiInputPort) -> Self {
        Self {
            name: name.clone(),
            id: p.id(),
        }
    }
    pub fn simulation() -> Self {
        Self {
            name: SIMULATEDMIDI.to_string(),
            id: SIMULATEDMIDI.to_string(),
        }
    }
    pub fn is_simulation(&self) -> bool {
        self.name.contains(SIMULATEDMIDI) && self.id.contains(SIMULATEDMIDI)
    }
}

enum Connection {
    None,
    Simulation(JoinHandle<()>),
    // Stored for its RAII side effect: dropping the connection stops the midir thread.
    #[allow(dead_code)]
    Device(MidiInputConnection<()>),
}

#[derive(Clone)]
pub enum Input {
    Simulation(String),
    Device(MidiPort),
}

pub struct Midi {
    input: Input,
    connection: Mutex<Connection>,
}

impl Midi {
    pub fn new_device(port: &MidiPort) -> Self {
        match port.is_simulation() {
            true => {
                let looop = simulation::setting();
                Self {
                    input: Input::Simulation(format!("{}", looop.unwrap())),
                    connection: Mutex::new(Connection::None),
                }
            }
            false => Self {
                input: Input::Device(port.clone()),
                connection: Mutex::new(Connection::None),
            },
        }
    }

    pub fn new_simulation(looop: &str) -> Self {
        Self {
            input: Input::Simulation(format!("{}", looop)),
            connection: Mutex::new(Connection::None),
        }
    }

    pub fn connect(&self) -> Result<Input, String> {
        // no op
        Ok(self.input.clone())
    }

    pub fn start_event_stream(
        &self,
        event_sender: event::EventSender,
        error_sender: event::ErrorSender,
        debug_handle: &Option<DebugServerHandle>,
    ) {
        match &self.input {
            Input::Simulation(spec) => {
                self.start_simulation_stream(
                    spec,
                    event_sender,
                    error_sender,
                    debug_handle.clone(),
                );
            }
            Input::Device(port) => {
                debug_assert!(!port.is_simulation());
                self.start_device_stream(port, event_sender, error_sender, debug_handle.clone());
            }
        }
    }

    pub fn stream_done(&self) -> bool {
        match self.connection.lock().unwrap().deref() {
            Connection::Simulation(handle) => handle.is_finished(),
            Connection::Device(_) => false,
            Connection::None => false,
        }
    }

    fn start_simulation_stream(
        &self,
        spec: &str,
        event_sender: event::EventSender,
        error_sender: event::ErrorSender,
        debug_handle: Option<DebugServerHandle>,
    ) {
        let handle =
            midi_simulation::start_stream(&spec, event_sender, error_sender, debug_handle.clone());
        *self.connection.lock().unwrap() = Connection::Simulation(handle);
    }

    fn start_device_stream(
        &self,
        wanted_port: &MidiPort,
        event_sender: event::EventSender,
        error_sender: event::ErrorSender,
        debug_handle: Option<DebugServerHandle>,
    ) {
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
                *self.connection.lock().unwrap() = Connection::Device(conn);
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
        *self.connection.lock().unwrap() = Connection::None;
    }
}

pub fn list_midi_ports() -> Vec<MidiPort> {
    if crate::simulation::enabled() {
        return vec![MidiPort::simulation()];
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
