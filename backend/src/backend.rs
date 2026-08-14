#![allow(dead_code, unused)]

use crate::{
    debug::DebugHandle,
    event,
    microphone::{self, Microphone},
    midi,
};

pub type MidiPort = midi::MidiPort;

enum Source {
    Microphone(microphone::Microphone),
    Midi(midi::Midi),
}

pub struct Backend {
    source: Option<Source>,
    debug_handle: Option<DebugHandle>,
}

impl Backend {
    pub fn new() -> Self {
        Self {
            source: None,
            debug_handle: None,
        }
    }

    pub fn new_debug() -> Self {
        Self {
            source: None,
            debug_handle: Some(DebugHandle::new()),
        }
    }

    pub fn list_midi_ports() -> Vec<MidiPort> {
        midi::list_midi_ports()
    }

    pub fn select_midi_port(&mut self, port: &MidiPort) {
        assert!(self.source.is_none());
        self.source = Some(Source::Midi(midi::Midi::new(port)));
    }

    pub fn select_microphone(&mut self) {
        assert!(self.source.is_none());
        self.source = Some(Source::Microphone(Microphone::new()));
    }

    fn start_midi_stream(
        midi: &midi::Midi,
        event_sender: event::EventSender,
        error_sender: event::ErrorSender,
        debug_handle: &Option<DebugHandle>,
    ) {
        midi.start_event_stream(event_sender, error_sender, debug_handle);
    }

    fn start_microphone_stream(
        mic: &microphone::Microphone,
        event_sender: event::EventSender,
        error_sender: event::ErrorSender,
        debug_handle: &Option<DebugHandle>,
    ) {
        mic.start_stream(event_sender, error_sender, debug_handle);
    }

    pub fn start_stream(&self, event_sender: event::EventSender, error_sender: event::ErrorSender) {
        assert!(!self.source.is_none());
        match self.source.as_ref().unwrap() {
            Source::Midi(midi) => {
                Self::start_midi_stream(midi, event_sender, error_sender, &self.debug_handle);
            }
            Source::Microphone(microphone) => {
                Self::start_microphone_stream(
                    microphone,
                    event_sender,
                    error_sender,
                    &self.debug_handle,
                );
            }
        }
    }

    pub fn disconnect(&mut self) {
        if self.source.is_none() {
            return;
        }
        match self.source.as_ref().unwrap() {
            Source::Midi(midi) => {
                midi.disconnect();
            }
            Source::Microphone(microphone) => {
                microphone.disconnect();
            }
        }
        self.source = None;
    }
}

pub fn test_log() {
    log::trace!("backend test log trace");
    log::info!("backend test log info");
    log::error!("backend test log error");
}
