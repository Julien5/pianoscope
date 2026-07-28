use std::{
    sync::{
        atomic::{AtomicBool, Ordering},
        Arc, Mutex,
    },
    thread,
    time::Duration,
};

use crate::midi::{format_midi_event, EventSender};

pub fn setting() -> Option<String> {
    let val = std::env::var("SIMULATION").ok().or_else(|| {
        #[cfg(target_os = "android")]
        {
            use crate::init::android;
            android::system_property("debug.nano.sim")
        }
        #[cfg(not(target_os = "android"))]
        {
            None
        }
    })?;
    if val.is_empty() {
        return None;
    }
    if val == "infinity" || val.parse::<u32>().is_ok() {
        Some(val)
    } else {
        None
    }
}

pub fn enabled() -> bool {
    setting().is_some()
}

pub fn infinite() -> bool {
    matches!(setting().as_deref(), Some("infinity"))
}

pub fn loop_count() -> u32 {
    setting().and_then(|s| s.parse::<u32>().ok()).unwrap_or(0)
}

const SCALE_NOTES: &[u8] = &[
    48, 50, 52, 53, 55, 57, 59, 60, 62, 64, 65, 67, 69, 71, 72, 71, 69, 67, 65, 64, 62, 60, 59, 57,
    55, 53, 52, 50, 48,
];
static SIM_STOP: Mutex<Option<Arc<AtomicBool>>> = Mutex::new(None);

pub fn start_stream(sender: EventSender) {
    let stop = Arc::new(AtomicBool::new(false));
    *SIM_STOP.lock().unwrap() = Some(stop.clone());

    let loops = if infinite() { u32::MAX } else { loop_count() };

    thread::Builder::new()
        .name("nano-midi-sim".into())
        .spawn(move || {
            sender("CONNECTED".to_string());

            for _ in 0..loops {
                if stop.load(Ordering::Relaxed) {
                    return;
                }
                for &note in SCALE_NOTES {
                    if stop.load(Ordering::Relaxed) {
                        return;
                    }
                    let msg_on = format_midi_event(&[0x90, note, 0x40]).unwrap_or_default();
                    sender(msg_on);
                    thread::sleep(Duration::from_millis(150));

                    if stop.load(Ordering::Relaxed) {
                        return;
                    }
                    let msg_off = format_midi_event(&[0x80, note, 0x00]).unwrap_or_default();
                    sender(msg_off);
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
