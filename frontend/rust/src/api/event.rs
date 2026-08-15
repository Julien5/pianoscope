pub use backend::event::{MidiEvent, Status};

#[flutter_rust_bridge::frb(mirror(MidiEvent))]
pub struct _MidiEvent {
    pub status: Status,
    pub velocity: u32,
    pub note: u8,
    pub note_name: String,
    pub raw: Vec<u8>,
}

#[flutter_rust_bridge::frb(mirror(Status))]
pub enum _Status {
    NoteOn,
    NoteOff,
}
