pub mod detection;
mod hardware;

use std::sync::Mutex;

use crate::debug::packets::{AudioDebugPacket, EventDebugPacket};
use crate::debug::DebugServerHandle;
use crate::event::{self, MidiEvent, Status};
use crate::microphone::detection::PitchDetector;

pub struct Microphone {
    connection: hardware::Connection,
    source: Mutex<hardware::Input>,
}

pub fn wavfile(filename: &str) -> hardware::Wavfile {
    hardware::Wavfile {
        path: std::path::PathBuf::from(filename),
        paced: true,
        looped: false,
    }
}

impl Microphone {
    pub fn new_device() -> Self {
        let source = hardware::Input::Device(None);
        Self {
            connection: hardware::Connection::new(),
            source: Mutex::new(source),
        }
    }

    pub fn new_wavfile(path: &str) -> Self {
        let source = hardware::Input::Simulation(wavfile(path));
        Self {
            connection: hardware::Connection::new(),
            source: Mutex::new(source),
        }
    }

    pub fn start_stream(
        &self,
        event_sender: event::EventSender,
        error_sender: event::ErrorSender,
        debug_handle: &Option<DebugServerHandle>,
    ) {
        // Build the recognizer inside the processing thread: `PitchRecognizer`
        // owns a `!Send` pitch detector, so only its factory crosses the thread
        // boundary.
        let error_sink: hardware::ErrorSink = error_sender.clone();
        let error_sender_factory = error_sender.clone();
        let debug_handle = debug_handle.clone();
        let factory: hardware::SampleProcessorFactory = Box::new(move || {
            Box::new(PitchRecognizer::new(
                event_sender,
                error_sender_factory,
                debug_handle,
            ))
        });
        let source = self.source.lock().unwrap().clone();
        if let Err(e) = self.connection.start(source, factory, error_sink) {
            error_sender(e.to_string());
        }
    }

    pub fn disconnect(&self) {
        self.connection.stop();
    }

    pub fn stream_done(&self) -> bool {
        self.connection.stream_done()
    }
}

impl Default for Microphone {
    fn default() -> Self {
        Self {
            connection: hardware::Connection::new(),
            source: Mutex::new(hardware::Input::Device(None)),
        }
    }
}

/// Recognizes note on/off events from windows of raw samples.
///
/// Owns the detection state and is mutated in place by the single processing
/// thread via `SampleProcessor::process`.
struct PitchRecognizer {
    pitch_detector: PitchDetector,
    debug_handle: Option<DebugServerHandle>,
    event_sender: event::EventSender,
}

impl PitchRecognizer {
    fn new(
        event_sender: event::EventSender,
        _error_sender: event::ErrorSender,
        debug_handle: Option<DebugServerHandle>,
    ) -> Self {
        Self {
            pitch_detector: PitchDetector::new(),
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
                AudioDebugPacket::from_samples(&block, self.pitch_detector.stats())
                    .as_json()
                    .as_bytes(),
            );
        }
        let status = if on { Status::NoteOn } else { Status::NoteOff };
        let velocity = 0x40;
        if let Some(event) = MidiEvent::from_note_status(&pitch, status, velocity) {
            if let Some(debug) = &self.debug_handle {
                debug.stream_data(&EventDebugPacket::from_event(&event).as_json().as_bytes());
            }
            (self.event_sender)(event);
        }
    }
    fn set_sample_rate(&mut self, sample_rate: u32) {
        self.pitch_detector.set_sample_rate(sample_rate);
    }
}
