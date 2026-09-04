use std::{
    sync::{
        atomic::{AtomicBool, Ordering},
        Arc, Mutex,
    },
    thread,
    time::Duration,
};

use crate::{
    debug::{packets::EventDebugPacket, DebugServerHandle},
    event::{ErrorSender, EventSender, MidiEvent, Status},
};

pub fn infinite(looop: &str) -> bool {
    matches!(looop, "infinity")
}

pub fn loop_count(looop: &str) -> u32 {
    looop.parse::<u32>().unwrap_or(0)
}

const SCALE_NOTES: &[&str] = &[
    "C3", "D3", "E3", "F3", "G3", "A3", "B3", "C4", "D4", "E4", "F4", "G4", "A4", "B4", "C5", "B4",
    "A4", "G4", "F4", "E4", "D4", "C4", "B3", "A3", "G3", "F3", "E3", "D3", "C3",
];

static SIM_STOP: Mutex<Option<Arc<AtomicBool>>> = Mutex::new(None);

pub fn start_stream(
    looop: &str,
    sender: EventSender,
    _error_sender: ErrorSender,
    debug_handle: Option<DebugServerHandle>,
) -> thread::JoinHandle<()> {
    let stop = Arc::new(AtomicBool::new(false));
    *SIM_STOP.lock().unwrap() = Some(stop.clone());

    let loops = if infinite(&looop) {
        u32::MAX
    } else {
        loop_count(&looop)
    };

    thread::Builder::new()
        .name("nano-midi-sim".into())
        .spawn(move || {
            for _ in 0..loops {
                if stop.load(Ordering::Relaxed) {
                    return;
                }
                for &note in SCALE_NOTES {
                    if stop.load(Ordering::Relaxed) {
                        return;
                    }
                    if let Some(event) = MidiEvent::from_note_status(note, Status::NoteOn, 0x40) {
                        sender(event);
                    }
                    thread::sleep(Duration::from_millis(250));

                    if stop.load(Ordering::Relaxed) {
                        return;
                    }
                    if let Some(event) = MidiEvent::from_note_status(note, Status::NoteOff, 0) {
                        if let Some(debugger) = &debug_handle {
                            debugger.stream_data(
                                &EventDebugPacket::from_event(&event).as_json().as_bytes(),
                            );
                        }
                        sender(event);
                    }
                    thread::sleep(Duration::from_millis(30));
                }
            }
        })
        .expect("failed to spawn midi simulation thread")
}

pub fn disconnect_midi() {
    if let Some(stop) = SIM_STOP.lock().unwrap().take() {
        stop.store(true, Ordering::Relaxed);
    }
}
