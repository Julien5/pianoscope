#![allow(non_snake_case)]

pub use backend::backend::Backend;
pub use backend::backend::MidiPort;

use crate::api::event::Event;
use crate::frb_generated::StreamSink;
use flutter_rust_bridge::frb;
use std::sync::Arc;

#[frb(mirror(MidiPort))]
pub struct _MidiPort {
    pub name: String,
    pub id: String,
}

#[frb(sync)]
pub fn list_midi_ports() -> Vec<MidiPort> {
    Backend::list_midi_ports()
}

#[frb(sync)]
pub fn simulation_setting() -> Option<String> {
    backend::simulation::setting()
}

#[frb(opaque)]
pub struct Bridge {
    backend: backend::backend::Backend,
}

impl Bridge {
    pub fn new() -> Self {
        Self {
            backend: Backend::new_debug(),
        }
    }

    pub fn select_midi(&mut self, port: &MidiPort) {
        self.backend.select_midi_port(port)
    }

    pub fn select_microphone(&mut self) {
        self.backend.select_microphone();
    }

    pub fn start_stream(&mut self, sink: StreamSink<Event>, error_sink: StreamSink<String>) {
        let sender = Arc::new(move |event| drop(sink.add(event)));
        let error_sender = Arc::new(move |msg| drop(error_sink.add(msg)));
        self.backend.start_stream(sender, error_sender);
    }

    pub fn disconnect(&mut self) {
        self.backend.disconnect();
    }
}
