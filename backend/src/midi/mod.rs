use midir::{MidiInput, MidiInputConnection, MidiInputPort};
use std::ops::Deref;
use std::sync::mpsc::{sync_channel, Receiver, RecvTimeoutError, SyncSender};
use std::sync::Mutex;
use std::thread::{spawn, JoinHandle};
use std::time::Duration;
mod filter;
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

struct MidiDevice {
    pub input: MidiInputConnection<()>,
    pub consumer_thread: JoinHandle<()>,
}

struct MidiSimulation {
    pub thread: JoinHandle<()>,
}

enum Connection {
    None,
    Simulation(MidiSimulation),
    Device(MidiDevice),
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
            Connection::Simulation(handle) => handle.thread.is_finished(),
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
        *self.connection.lock().unwrap() =
            Connection::Simulation(MidiSimulation { thread: handle });
    }

    fn start_device_stream(
        &self,
        wanted_port: &MidiPort,
        _event_sender: event::EventSender,
        error_sender: event::ErrorSender,
        _debug_handle: Option<DebugServerHandle>,
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

        // High channel capacity to accommodate continuous streams without blocking
        let (sender, receiver) = sync_channel::<Vec<u8>>(4096);

        let send_closure = Self::make_send_closure(sender);
        let consumer_thread = spawn(Self::make_consumer_closure(
            receiver,
            _event_sender,
            _debug_handle,
        ));

        match midi_in.connect(&in_port, "nano", send_closure, ()) {
            Ok(conn) => {
                *self.connection.lock().unwrap() = Connection::Device(MidiDevice {
                    input: conn,
                    consumer_thread,
                });
            }
            Err(e) => {
                log::trace!("error: {:?}", e);
                error_sender(format!("{e}"));
            }
        }
    }

    fn make_send_closure(
        sender: SyncSender<Vec<u8>>,
    ) -> impl FnMut(u64, &[u8], &mut ()) + Send + 'static {
        let mut note_count = 0;
        let mut total_bytes = 0;
        let mut dropped_count = 0;
        let mut last_note_msg: Vec<u8> = Vec::new();

        move |_timestamp: u64, bytes: &[u8], _data: &mut ()| {
            let mut offset = 0;

            while offset < bytes.len() {
                let status = bytes[offset];

                // 1. Skip Real-Time single-byte messages (0xF8..=0xFF)
                if status >= 0xF8 {
                    offset += 1;
                    continue;
                }

                let msg_len = Self::get_message_length_fast(status, &bytes[offset..]);
                let msg = &bytes[offset..offset + msg_len];
                let status_nibble = status & 0xF0;

                // 2. Process Note On (0x90) and Note Off (0x80) events
                if status_nibble == 0x80 || status_nibble == 0x90 {
                    let is_duplicate = msg == last_note_msg.as_slice();

                    if !is_duplicate {
                        if sender.try_send(msg.to_vec()).is_ok() {
                            last_note_msg = msg.to_vec();
                            note_count += 1;
                            total_bytes += msg_len;

                            if note_count % 1_000 == 0 {
                                log::trace!(
                                    "sent {} k-notes ({} KiB)",
                                    note_count / 1000,
                                    total_bytes / 1024
                                );
                            }
                        } else {
                            dropped_count += 1;
                            if dropped_count % 1_000 == 0 {
                                log::warn!(
                                    "midi queue full, dropped {} note messages",
                                    dropped_count
                                );
                            }
                        }
                    }
                }

                offset += msg_len;
            }
        }
    }

    /// Determines message length for complete MIDI slices starting at slice[0].
    fn get_message_length_fast(status: u8, slice: &[u8]) -> usize {
        let status_nibble = status & 0xF0;

        match status_nibble {
            0x80 | 0x90 | 0xA0 | 0xB0 | 0xE0 => 3, // Note Off, Note On, Poly Touch, CC, Pitch Bend
            0xC0 | 0xD0 => 2,                      // Program Change, Channel Pressure
            0xF0 => match status {
                0xF1 | 0xF3 => 2, // MTC Quarter Frame, Song Select
                0xF2 => 3,        // Song Position Pointer
                0xF0 => {
                    // SysEx: find End of SysEx (0xF7)
                    slice
                        .iter()
                        .position(|&b| b == 0xF7)
                        .map_or(1, |idx| idx + 1)
                }
                _ => 1, // Tune Request (0xF6), etc.
            },
            _ => 1,
        }
    }

    fn make_consumer_closure(
        receiver: Receiver<Vec<u8>>,
        event_sender: event::EventSender,
        debug_handle: Option<DebugServerHandle>,
    ) -> impl FnMut() {
        let mut filter = filter::MidiFilter::new();
        let callback_sender = event_sender.clone();
        move || loop {
            match receiver.recv_timeout(Duration::from_secs_f64(0.250)) {
                Ok(bytes) => {
                    Self::dispatch_event(&bytes, &mut filter, &callback_sender, &debug_handle);
                }
                Err(RecvTimeoutError::Timeout) => {}
                // The midir connection was dropped: nothing left to filter.
                Err(RecvTimeoutError::Disconnected) => break,
            }
        }
    }

    /// Parses a complete raw MIDI slice into a MidiEvent, checks filters, and forwards it.
    fn dispatch_event(
        msg: &[u8],
        filter: &mut filter::MidiFilter,
        callback_sender: &event::EventSender,
        debug_handle: &Option<DebugServerHandle>,
    ) {
        if let Some(event) = MidiEvent::from_midi(msg) {
            if !filter.should_forward(msg) {
                // Skip event according to filter rules
            } else {
                log::trace!("send event: {:?}", event);
                if let Some(debugger) = debug_handle {
                    debugger
                        .stream_data(&EventDebugPacket::from_event(&event).as_json().as_bytes());
                }
                callback_sender(event);
                log::trace!("send event done");
            }
        } else {
            log::trace!("unrecognized midi bytes: {:?}", msg);
        }
    }

    pub fn disconnect(&self) {
        log::trace!("disconnect: start");
        if crate::simulation::enabled() {
            midi_simulation::disconnect_midi();
        }
        let conn = std::mem::replace(&mut *self.connection.lock().unwrap(), Connection::None);
        match conn {
            Connection::Device(connection) => {
                #[cfg(target_os = "android")]
                {
                    crate::init::android::with_attached_jvm(|| {
                        let _ = connection.input.close();
                    });
                }
                #[cfg(not(target_os = "android"))]
                {
                    log::trace!("close connection");
                    let _ = connection.input.close();
                }
                log::trace!("join thread");
                let _ = connection.consumer_thread.join();
            }
            Connection::Simulation(handle) => {
                let _ = handle.thread.join();
            }
            Connection::None => {}
        }
        log::trace!("disconnect: done");
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
