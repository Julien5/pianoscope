use crate::api::event::Event;
use crate::frb_generated::StreamSink;
use backend::midi::{self, Midi};
use std::sync::Arc;

#[flutter_rust_bridge::frb(sync)]
pub fn list_midi_ports() -> Vec<String> {
    midi::list_midi_ports()
}

pub struct Bridge {
    midi: Midi,
    debug: Option<backend::debug::DebugHandle>,
}

impl Bridge {
    pub fn new() -> Self {
        Self {
            midi: backend::midi::Midi::new(),
            debug: Some(backend::debug::DebugHandle::new()),
        }
    }

    pub fn connect_midi(&self, port_index: u32) -> Result<String, String> {
        self.midi.connect(port_index)
    }

    pub fn start_midi_event_stream(&self, sink: StreamSink<Event>, error_sink: StreamSink<String>) {
        let sender = Arc::new(move |event| drop(sink.add(event)));
        let error_sender = Arc::new(move |msg| drop(error_sink.add(msg)));
        self.midi
            .start_event_stream(sender, error_sender, &self.debug);
    }

    pub fn disconnect_midi(&self) {
        self.midi.disconnect();
    }
}
