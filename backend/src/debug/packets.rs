use serde::Serialize;

use base64::engine::general_purpose::STANDARD as BASE64;
use base64::Engine;

use crate::event::MidiEvent;
use crate::microphone::detection::PitchStats;

fn f32_slice_to_f64_base64(data: &[f32]) -> String {
    let bytes: Vec<u8> = data
        .iter()
        .flat_map(|&val| (val as f64).to_le_bytes())
        .collect();
    BASE64.encode(&bytes)
}

#[derive(Clone, Serialize)]
pub struct AudioDatablock {
    pub audio_base64: String,
    pub pitch_stats: PitchStats,
}

#[derive(Clone, Serialize)]
pub struct AudioDebugPacket {
    audio: AudioDatablock,
}

impl AudioDebugPacket {
    pub fn as_json(&self) -> String {
        serde_json::to_string(self).unwrap()
    }
    pub fn from_samples(samples: &[f32], pitch_stats: PitchStats) -> Self {
        Self {
            audio: AudioDatablock {
                audio_base64: f32_slice_to_f64_base64(samples),
                pitch_stats,
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
