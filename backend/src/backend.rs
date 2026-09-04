#![allow(dead_code, unused)]

use crate::{
    debug::DebugServerHandle,
    event,
    microphone::{self, Microphone},
    midi, simulation,
};

pub type MidiPort = midi::MidiPort;

enum Source {
    Microphone(microphone::Microphone),
    Midi(midi::Midi),
}

pub struct Backend {
    source: Option<Source>,
    debug_server: Option<DebugServerHandle>,
}

impl Backend {
    pub fn new() -> Self {
        Self {
            source: None,
            debug_server: None,
        }
    }

    pub fn new_debug_server() -> Self {
        Self {
            source: None,
            debug_server: Some(DebugServerHandle::new()),
        }
    }

    pub fn list_midi_ports() -> Vec<MidiPort> {
        midi::list_midi_ports()
    }

    pub fn select_midi_port(&mut self, port: &MidiPort) {
        assert!(self.source.is_none());
        self.source = Some(Source::Midi(midi::Midi::new_device(port)));
    }

    pub fn select_midi_simulation(&mut self, looop: &str) {
        assert!(self.source.is_none());
        self.source = Some(Source::Midi(midi::Midi::new_simulation(looop)));
    }

    pub fn select_microphone(&mut self) {
        assert!(self.source.is_none());
        let source = if simulation::enabled() {
            Microphone::new_wavfile(&simulation::setting().unwrap())
        } else {
            Microphone::new_device()
        };
        self.source = Some(Source::Microphone(source));
    }

    pub fn select_wavfile(&mut self, path: &str) {
        assert!(self.source.is_none());
        let source = Microphone::new_wavfile(path);
        self.source = Some(Source::Microphone(source));
    }

    fn start_midi_stream(
        midi: &midi::Midi,
        event_sender: event::EventSender,
        error_sender: event::ErrorSender,
        debug_handle: &Option<DebugServerHandle>,
    ) {
        midi.start_event_stream(event_sender, error_sender, debug_handle);
    }

    fn start_microphone_stream(
        mic: &microphone::Microphone,
        event_sender: event::EventSender,
        error_sender: event::ErrorSender,
        debug_handle: &Option<DebugServerHandle>,
    ) {
        mic.start_stream(event_sender, error_sender, debug_handle);
    }

    pub fn start_stream(&self, event_sender: event::EventSender, error_sender: event::ErrorSender) {
        assert!(!self.source.is_none());
        match self.source.as_ref().unwrap() {
            Source::Midi(midi) => {
                Self::start_midi_stream(midi, event_sender, error_sender, &self.debug_server);
            }
            Source::Microphone(microphone) => {
                Self::start_microphone_stream(
                    microphone,
                    event_sender,
                    error_sender,
                    &self.debug_server,
                );
            }
        }
    }

    pub fn stream_done(&self) -> bool {
        match self.source.as_ref() {
            None => false,
            Some(Source::Midi(midi)) => midi.stream_done(),
            Some(Source::Microphone(microphone)) => microphone.stream_done(),
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
