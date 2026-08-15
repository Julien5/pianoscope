pub mod detection;
mod hardware;

use std::sync::Mutex;

use crate::debug::packets::{EventDebugPacket, SamplesDebugPacket};
use crate::debug::DebugHandle;
use crate::event::{self, MidiEvent, Status};
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
        let sample_processor =
            PitchRecognizer::new(event_sender, error_sender.clone(), debug_handle.clone());
        let error_sink: hardware::ErrorSink = error_sender.clone();
        let source = self.source.lock().unwrap().clone();
        if let Err(e) = self
            .handler
            .start(source, Box::new(sample_processor), error_sink)
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

/// Recognizes note on/off events from windows of raw samples.
///
/// Owns the detection state and is mutated in place by the single processing
/// thread via `SampleProcessor::process`.
struct PitchRecognizer {
    pitch_detector: PitchDetector,
    sounding: bool,
    debug_handle: Option<DebugHandle>,
    event_sender: event::EventSender,
}

impl PitchRecognizer {
    fn new(
        event_sender: event::EventSender,
        _error_sender: event::ErrorSender,
        debug_handle: Option<DebugHandle>,
    ) -> Self {
        Self {
            pitch_detector: PitchDetector::new(),
            sounding: false,
            debug_handle,
            event_sender,
        }
    }
}

impl hardware::SampleProcessor for PitchRecognizer {
    fn process(&mut self, block: &[f32]) {
        self.pitch_detector.update(block);
        let pitch = self.pitch_detector.pitch();
        let on = self.pitch_detector.on();
        if let Some(debug) = &self.debug_handle {
            debug.stream_data(
                SamplesDebugPacket::from_samples(&block, &self.pitch_detector)
                    .as_json()
                    .as_bytes(),
            );
        }
        if on != self.sounding {
            self.sounding = on;
            let status = if on { Status::NoteOn } else { Status::NoteOff };
            if let Some(event) = MidiEvent::from_note_status(&pitch, status, 0x40) {
                if let Some(debug) = &self.debug_handle {
                    debug.stream_data(&EventDebugPacket::from_event(&event).as_json().as_bytes());
                }
                (self.event_sender)(event);
            }
        }
    }
}
