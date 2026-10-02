use std::collections::HashMap;
use std::time::{Duration, Instant};

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub struct MidiNote {
    pub channel: u8,
    pub note_number: u8,
}

pub struct MidiFilter {
    active_notes: HashMap<MidiNote, Instant>,
    debounce_duration: Duration,
}

impl MidiFilter {
    pub fn new(debounce_ms: u64) -> Self {
        Self {
            active_notes: HashMap::new(),
            debounce_duration: Duration::from_millis(debounce_ms),
        }
    }

    /// Evaluates dynamic byte slices safely. Returns `true` if event should be forwarded.
    pub fn should_forward(&mut self, bytes: &[u8]) -> bool {
        // Ignore empty or non-standard payload lengths
        if bytes.is_empty() {
            return false;
        }

        let status = bytes[0];

        // 1. Instantly drop Real-Time / Active Sensing / System Realtime bytes (0xF8..=0xFF)
        if status >= 0xF8 {
            return false;
        }

        // We need at least status + note + velocity for NoteOn / NoteOff
        if bytes.len() < 3 {
            return true; // Pass through non-note short messages (e.g., Program Change)
        }

        let msg_type = status & 0xF0;
        let channel = status & 0x0F;
        let note_number = bytes[1];
        let velocity = bytes[2];
        let note = MidiNote {
            channel,
            note_number,
        };
        let now = Instant::now();

        match msg_type {
            // Note On (0x90 / 144)
            0x90 => {
                if velocity > 0 {
                    // Check if note is already active or in debounce window
                    if let Some(&last_time) = self.active_notes.get(&note) {
                        if now.duration_since(last_time) < self.debounce_duration {
                            return false; // Drop rapid hardware chatter
                        }
                        return false; // Drop duplicate NoteOn (already active)
                    }

                    // First NoteOn -> Register active state and timestamp
                    self.active_notes.insert(note, now);
                    true
                } else {
                    // Velocity 0 is standard MIDI for Note Off
                    self.handle_note_off(note, now)
                }
            }

            // Note Off (0x80 / 128)
            0x80 => self.handle_note_off(note, now),

            // Pass Control Change (0xB0), Pitch Bend (0xE0), etc.
            _ => true,
        }
    }

    fn handle_note_off(&mut self, note: MidiNote, now: Instant) -> bool {
        if let Some(pressed_at) = self.active_notes.remove(&note) {
            // Optional: Drop NoteOff if it happened unnaturally fast (< debounce threshold)
            if now.duration_since(pressed_at) < self.debounce_duration {
                return false;
            }
            true // Forward legitimate NoteOff
        } else {
            false // Drop redundant / duplicate NoteOff
        }
    }
}
