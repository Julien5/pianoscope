use serde::Serialize;

use base64::engine::general_purpose::STANDARD as BASE64;
use base64::Engine;

use crate::event::MidiEvent;

fn f32_slice_to_f64_base64(data: &[f32]) -> String {
    let bytes: Vec<u8> = data
        .iter()
        .flat_map(|&val| (val as f64).to_le_bytes())
        .collect();
    BASE64.encode(&bytes)
}

#[derive(Clone, Serialize)]
pub struct AudioDatablock {
    pub base64: String,
}

#[derive(Clone, Serialize)]
pub struct SamplesDebugPacket {
    audio: AudioDatablock,
}

impl SamplesDebugPacket {
    pub fn as_json(&self) -> String {
        serde_json::to_string(self).unwrap()
    }
    pub fn from_samples(samples: &[f32]) -> Self {
        Self {
            audio: AudioDatablock {
                base64: f32_slice_to_f64_base64(samples),
            },
        }
    }
}

#[derive(Clone, Serialize)]
pub struct EventDebugPacket {
    event: MidiEvent,
}

impl EventDebugPacket {
    pub fn as_json(&self) -> String {
        serde_json::to_string(self).unwrap()
    }
    pub fn from_event(event: &MidiEvent) -> Self {
        Self {
            event: event.clone(),
        }
    }
}
