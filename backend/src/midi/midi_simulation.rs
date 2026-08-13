use std::{
    sync::{
        atomic::{AtomicBool, Ordering},
        Arc, Mutex,
    },
    thread,
    time::Duration,
};

use crate::{
    debug::DebugHandle,
    event::{ErrorSender, Event, EventSender, Status},
    simulation,
};

pub fn infinite() -> bool {
    matches!(simulation::setting().as_deref(), Some("infinity"))
}

pub fn loop_count() -> u32 {
    simulation::setting()
        .and_then(|s| s.parse::<u32>().ok())
        .unwrap_or(0)
}

const SCALE_NOTES: &[&str] = &[
    "C3", "D3", "E3", "F3", "G3", "A3", "B3", "C4", "D4", "E4", "F4", "G4", "A4", "B4", "C5", "B4",
    "A4", "G4", "F4", "E4", "D4", "C4", "B3", "A3", "G3", "F3", "E3", "D3", "C3",
];

static SIM_STOP: Mutex<Option<Arc<AtomicBool>>> = Mutex::new(None);

pub fn start_stream(
    sender: EventSender,
    _error_sender: ErrorSender,
    debug_handle: Option<DebugHandle>,
) {
    let stop = Arc::new(AtomicBool::new(false));
    *SIM_STOP.lock().unwrap() = Some(stop.clone());

    let loops = if infinite() { u32::MAX } else { loop_count() };

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
                    if let Some(event) = Event::from_note_status(note, Status::NoteOn, 0x40) {
                        sender(event);
                    }
                    thread::sleep(Duration::from_millis(500));

                    if stop.load(Ordering::Relaxed) {
                        return;
                    }
                    if let Some(event) = Event::from_note_status(note, Status::NoteOff, 0) {
                        if let Some(debugger) = &debug_handle {
                            debugger.stream_data(event.as_json().as_bytes());
                        }
                        sender(event);
                    }
                    thread::sleep(Duration::from_millis(30));
                }
            }
        })
        .ok();
}

pub fn disconnect_midi() {
    if let Some(stop) = SIM_STOP.lock().unwrap().take() {
        stop.store(true, Ordering::Relaxed);
    }
}
