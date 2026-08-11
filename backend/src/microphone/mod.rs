pub mod hardware;

use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::{Arc, Mutex};

use crate::event::{self, Event, Status};

const ENERGY_THRESHOLD: f64 = 0.02;
const RECOGNIZED_NOTE: &str = "C4";
const RECOGNIZED_VELOCITY: u32 = 0x40;

pub struct Microphone {
    handler: hardware::AudioStreamHandler,
    source: Mutex<Option<hardware::Source>>,
}

impl Microphone {
    pub const fn new() -> Self {
        Self {
            handler: hardware::AudioStreamHandler::new(),
            source: Mutex::new(None),
        }
    }

    pub fn connect(&self, source: hardware::Source) -> Result<String, String> {
        let label = match &source {
            hardware::Source::InputDevice(None) => "Default microphone".to_string(),
            hardware::Source::InputDevice(Some(i)) => format!("Microphone {i}"),
            hardware::Source::File(file) => {
                hound::WavReader::open(&file.path).map_err(|e| e.to_string())?;
                file.path.display().to_string()
            }
        };
        *self.source.lock().unwrap() = Some(source);
        Ok(label)
    }

    pub fn start_stream(&self, sender: event::EventSender, error_sender: event::ErrorSender) {
        let Some(source) = self.source.lock().unwrap().take() else {
            error_sender("Not connected".to_string());
            return;
        };
        let energy_sink = threshold_recognizer(sender, error_sender.clone());
        let error_sink: hardware::ErrorSink = error_sender.clone();
        if let Err(e) = self.handler.start(source, energy_sink, error_sink) {
            error_sender(e.to_string());
        }
    }

    pub fn disconnect(&self) {
        self.handler.stop();
        *self.source.lock().unwrap() = None;
    }
}

impl Default for Microphone {
    fn default() -> Self {
        Self::new()
    }
}

/// Turns energy windows into note on/off events by thresholding.
///
/// A rising edge (silence → sound) emits a `NoteOn`, a falling edge emits a
/// `NoteOff`, both for a fixed placeholder note. Real note recognition will
/// replace this stand-in.
fn threshold_recognizer(
    sender: event::EventSender,
    error_sender: event::ErrorSender,
) -> hardware::EnergySink {
    let sounding = Arc::new(AtomicBool::new(false));
    Arc::new(move |energy: f64| {
        let on = energy >= ENERGY_THRESHOLD;
        if on != sounding.swap(on, Ordering::Relaxed) {
            let status = if on { Status::NoteOn } else { Status::NoteOff };
            match Event::from_note_status(RECOGNIZED_NOTE, status, RECOGNIZED_VELOCITY) {
                Some(event) => sender(event),
                None => error_sender("failed to build note event".to_string()),
            }
        }
    })
}
