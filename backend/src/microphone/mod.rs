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
        paced: false,  // false for tests
        looped: false, // false for tests
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
        let factory: hardware::SampleProcessorFactory =
            Box::new(move |parameters: &PitchRecognizerParameters| {
                Box::new(PitchRecognizer::new(
                    parameters,
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

#[derive(Clone, Debug)]
pub enum PitchRecognizerAlgorithm {
    McLeod,
    YIN,
    PYIN,
    Swipe,
    AutoCorrelation,
    Kord,
}

#[derive(Clone, Debug)]
pub struct PitchRecognizerParameters {
    algorithm: PitchRecognizerAlgorithm,
    sample_rate: u32,
    window_len: usize,
}

#[allow(dead_code)]
impl PitchRecognizerParameters {
    fn new_pyin(sample_rate: u32, window_len: usize) -> Self {
        Self {
            algorithm: PitchRecognizerAlgorithm::PYIN,
            sample_rate,
            window_len,
        }
    }
    fn new_mcleod(sample_rate: u32, window_len: usize) -> Self {
        Self {
            algorithm: PitchRecognizerAlgorithm::McLeod,
            sample_rate,
            window_len,
        }
    }
    fn new_swipe(sample_rate: u32, window_len: usize) -> Self {
        Self {
            algorithm: PitchRecognizerAlgorithm::Swipe,
            sample_rate,
            window_len,
        }
    }
    fn new_yin(sample_rate: u32, window_len: usize) -> Self {
        Self {
            algorithm: PitchRecognizerAlgorithm::YIN,
            sample_rate,
            window_len,
        }
    }
    fn new_autocorrelation(sample_rate: u32, window_len: usize) -> Self {
        Self {
            algorithm: PitchRecognizerAlgorithm::AutoCorrelation,
            sample_rate,
            window_len,
        }
    }
    fn new_kord(sample_rate: u32, window_len: usize) -> Self {
        Self {
            algorithm: PitchRecognizerAlgorithm::Kord,
            sample_rate,
            window_len,
        }
    }
}

struct PitchRecognizer {
    pitch_detector: PitchDetector,
    debug_handle: Option<DebugServerHandle>,
    event_sender: event::EventSender,
    last_event: Option<MidiEvent>,
}

impl PitchRecognizer {
    fn new(
        parameters: &PitchRecognizerParameters,
        event_sender: event::EventSender,
        _error_sender: event::ErrorSender,
        debug_handle: Option<DebugServerHandle>,
    ) -> Self {
        Self {
            pitch_detector: PitchDetector::new(parameters),
            debug_handle,
            event_sender,
            last_event: None,
        }
    }

    fn send(&mut self, event: &MidiEvent) {
        if let Some(debug) = &self.debug_handle {
            debug.stream_data(&EventDebugPacket::from_event(&event).as_json().as_bytes());
        }
        // log::trace!("send: {:?} status: {:?}", event.note_name, event.status);
        (self.event_sender)(event.clone());
        self.last_event = Some(event.clone());
    }
}

impl hardware::SampleProcessor for PitchRecognizer {
    fn process(&mut self, block: &[f32]) {
        self.pitch_detector.update(block);
        if let Some(debug) = &self.debug_handle {
            debug.stream_data(
                AudioDebugPacket::from_samples(&block, self.pitch_detector.stats())
                    .as_json()
                    .as_bytes(),
            );
        }
        let pitch = self.pitch_detector.pitch();
        let status = if self.pitch_detector.on() {
            Status::NoteOn
        } else {
            Status::NoteOff
        };
        let velocity = self.pitch_detector.stats().velocity();
        if let Some(event) = MidiEvent::from_note_status(&pitch, status, velocity) {
            if let Some(last_event) = &self.last_event {
                // end the last note.
                if last_event.status == Status::NoteOn && last_event.note != event.note {
                    self.send(&last_event.off_clone());
                }
            }
            self.send(&event);
        }
    }
}
