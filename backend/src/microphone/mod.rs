mod detection;
mod hardware;

use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::{Arc, Mutex};

use crate::debug::DebugHandle;
use crate::event::{self, Event, Status};
use crate::microphone::detection::PitchDetector;
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

fn threshold_recognizer(
    event_sender: event::EventSender,
    _error_sender: event::ErrorSender,
    debug_handle: Option<DebugHandle>,
) -> hardware::SamplesSink {
    let sounding = Arc::new(AtomicBool::new(false));
    let mut pitch_detector = PitchDetector::new();
    Arc::new(move |block: &[f32]| {
        pitch_detector.update(block);
        let pitch = pitch_detector.pitch();
        let on = !pitch.is_empty();
        if on != sounding.swap(on, Ordering::Relaxed) {
            let status = if on { Status::NoteOn } else { Status::NoteOff };
            let event = Event::from_note_status(&pitch, status, 0x40).unwrap();
            if let Some(debug) = &debug_handle {
                debug.stream_data(&event.as_json().as_bytes());
            }
            event_sender(event);
        }
    })
}
