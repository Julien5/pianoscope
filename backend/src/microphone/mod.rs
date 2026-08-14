mod hardware;

use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::{Arc, Mutex};

use crate::debug::DebugHandle;
use crate::event::{self, Event, Status};
use crate::simulation;

pub struct Microphone {
    handler: hardware::AudioStreamHandler,
    source: Mutex<hardware::Source>,
}

pub fn wavfile(filename: String) -> hardware::FileSource {
    hardware::FileSource {
        path: std::path::PathBuf::from(filename),
        paced: true,
        looped: true,
    }
}

impl Microphone {
    pub fn new() -> Self {
        let source = if simulation::enabled() {
            log::trace!("source is {}", simulation::setting().unwrap());
            hardware::Source::File(wavfile(simulation::setting().unwrap()))
        } else {
            log::trace!("source is audio (microphone)");
            hardware::Source::InputDevice(None)
        };
        Self {
            handler: hardware::AudioStreamHandler::new(),
            source: Mutex::new(source),
        }
    }

    pub fn start_stream(
        &self,
        event_sender: event::EventSender,
        error_sender: event::ErrorSender,
        debug_handle: &Option<DebugHandle>,
    ) {
        let sample_sink =
            threshold_recognizer(event_sender, error_sender.clone(), debug_handle.clone());
        let error_sink: hardware::ErrorSink = error_sender.clone();
        let source = self.source.lock().unwrap().clone();
        if let Err(e) = self
            .handler
            .start(source, sample_sink, error_sink, debug_handle)
        {
            error_sender(e.to_string());
        }
    }

    pub fn disconnect(&self) {
        self.handler.stop();
    }
}

impl Default for Microphone {
    fn default() -> Self {
        Self::new()
    }
}

fn compute_energy(samples: &[f32]) -> f64 {
    if samples.is_empty() {
        return 0.0;
    }
    //samples.iter().map(|x| x.abs()).fold(0f32 / 0f32, f32::max) as f64
    let sum_sq: f64 = samples.iter().map(|&s| (s as f64) * (s as f64)).sum();
    (sum_sq / samples.len() as f64).sqrt()
}

/// Turns energy windows into note on/off events by thresholding.
///
/// A rising edge (silence → sound) emits a `NoteOn`, a falling edge emits a
/// `NoteOff`, both for a fixed placeholder note. Real note recognition will
/// replace this stand-in.
fn threshold_recognizer(
    event_sender: event::EventSender,
    _error_sender: event::ErrorSender,
    debug_handle: Option<DebugHandle>,
) -> hardware::SamplesSink {
    let sounding = Arc::new(AtomicBool::new(false));
    Arc::new(move |block: &[f32]| {
        let energy = compute_energy(block);
        const ENERGY_THRESHOLD: f64 = 0.01;
        const RECOGNIZED_NOTE: &str = "C4";
        const RECOGNIZED_VELOCITY: u32 = 0x40;

        log::trace!(
            "run threshold recognizer: {:.5} / {:.5}",
            energy,
            ENERGY_THRESHOLD
        );
        let on = energy >= ENERGY_THRESHOLD;
        if on != sounding.swap(on, Ordering::Relaxed) {
            let status = if on { Status::NoteOn } else { Status::NoteOff };
            let event =
                Event::from_note_status(RECOGNIZED_NOTE, status, RECOGNIZED_VELOCITY).unwrap();
            if let Some(debug) = &debug_handle {
                debug.stream_data(&event.as_json().as_bytes());
            }
            event_sender(event);
        }
    })
}
