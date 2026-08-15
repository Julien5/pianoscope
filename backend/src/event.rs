use serde::{Deserialize, Serialize};
use std::sync::Arc;

pub const NOTE_NAMES: &[&str] = &[
    "C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B",
];

#[derive(Clone, Serialize, Deserialize)]
pub enum Status {
    NoteOn,
    NoteOff,
}

#[derive(Clone, Serialize, Deserialize)]
pub struct MidiEvent {
    pub status: Status,
    pub velocity: u32,
    pub note: u8,
    pub note_name: String,
    pub raw: Vec<u8>,
}

impl MidiEvent {
    pub fn from_midi(bytes: &[u8]) -> Option<Self> {
        if bytes.len() < 3 {
            return None;
        }
        let status_byte = bytes[0] & 0xF0;
        let note = bytes[1];
        let velocity = bytes[2];

        let status = if status_byte == 0x90 && velocity > 0 {
            Status::NoteOn
        } else {
            Status::NoteOff
        };

        let note_idx = (note % 12) as usize;
        let note_name = NOTE_NAMES[note_idx];
        let octave = (note / 12) as i32 - 1;
        let name = format!("{note_name}{octave}");

        Some(Self {
            status,
            velocity: velocity as u32,
            note,
            note_name: name,
            raw: bytes.to_vec(),
        })
    }

    pub fn from_note(name: &str) -> Option<Self> {
        Self::from_note_status(name, Status::NoteOn, 0x40)
    }

    pub fn from_note_status(name: &str, status: Status, velocity: u32) -> Option<Self> {
        let note = note_name_to_midi(name)?;
        let status_byte = match status {
            Status::NoteOn => 0x90,
            Status::NoteOff => 0x80,
        };
        Some(Self {
            status,
            velocity,
            note,
            note_name: name.to_string(),
            raw: vec![status_byte, note, velocity as u8],
        })
    }
}

fn note_name_to_midi(name: &str) -> Option<u8> {
    let name = name.trim();
    let (letter, rest) = name.split_at_checked(1)?;
    let semitone = match letter {
        "C" => 0,
        "D" => 2,
        "E" => 4,
        "F" => 5,
        "G" => 7,
        "A" => 9,
        "B" => 11,
        _ => return None,
    };
    let (accidental, octave_str) = match rest.chars().next() {
        Some('#') => (1, &rest[1..]),
        Some('b') => (-1, &rest[1..]),
        Some(_) => (0, rest),
        None => return None,
    };
    let octave: i32 = octave_str.parse().ok()?;
    let note = (octave + 1) * 12 + semitone + accidental;
    if !(0..=127).contains(&note) {
        return None;
    }
    Some(note as u8)
}

pub type EventSender = Arc<dyn Fn(MidiEvent) + Send + Sync>;
pub type ErrorSender = Arc<dyn Fn(String) + Send + Sync>;
