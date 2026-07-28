use crate::frb_generated::StreamSink;
use backend::midi::{self, Midi};
use std::sync::Arc;

#[flutter_rust_bridge::frb(sync)]
pub fn list_midi_ports() -> Vec<String> {
    midi::list_midi_ports()
}

pub struct Bridge {
    midi: Midi,
}

impl Bridge {
    pub const fn new() -> Self {
        Self {
            midi: backend::midi::Midi::new(),
        }
    }

    pub fn connect_midi(&self, port_index: u32) -> Result<String, String> {
        self.midi.connect(port_index)
    }

    pub fn start_midi_event_stream(&self, sink: StreamSink<String>) {
        let sender = Arc::new(move |msg| drop(sink.add(msg)));
        self.midi.start_event_stream(sender);
    }

    pub fn disconnect_midi(&self) {
        self.midi.disconnect();
    }
}
