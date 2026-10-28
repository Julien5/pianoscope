use crate::debug::packets::{AudioDebugPacket, EventDebugPacket};
use crate::event::{MidiEvent, Status};
use crate::microphone::detection::PitchDetector;
use crate::microphone::Senders;

pub trait BlockProcessor {
    fn process(&mut self, block: &[f32]);
}

#[derive(Clone)]
pub struct BlockProcessorParameters {
    pub sample_rate: u32,
    pub window_len: usize,
}

pub struct BlockProcessorFactory {
    pub senders: Senders,
    pub parameters: Option<BlockProcessorParameters>,
}

impl BlockProcessorFactory {
    pub fn create(self) -> Box<dyn BlockProcessor> {
        debug_assert!(self.parameters.is_some());
        Box::new(SimpleProcessor {
            senders: self.senders,
            pitch_detector: PitchDetector::new(&self.parameters.unwrap()),
            last_event: None,
        })
    }
}

struct SimpleProcessor {
    senders: Senders,
    pitch_detector: PitchDetector,
    last_event: Option<MidiEvent>,
}

impl SimpleProcessor {
    fn send(&mut self, event: &MidiEvent) {
        if let Some(debug) = &self.senders.debug_handle {
            debug.stream_data(&EventDebugPacket::from_event(&event).as_json().as_bytes());
        }
        log::trace!("send: {:?} status: {:?}", event.note_name, event.status);
        (self.senders.event_sender)(event.clone());
        self.last_event = Some(event.clone());
    }
}

impl BlockProcessor for SimpleProcessor {
    fn process(&mut self, block: &[f32]) {
        self.pitch_detector.update(block);
        if let Some(debug) = &self.senders.debug_handle {
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
        let confidence = self.pitch_detector.stats().confidence;
        if let Some(event) =
            MidiEvent::from_microphone_estimate(&pitch, &status, velocity, confidence)
        {
            if let Some(last_event) = &self.last_event {
                // end the last note.
                if last_event.status == Status::NoteOn && last_event.note != event.note {
                    self.send(&last_event.off_clone());
                }
            }
            self.send(&event);
        } else if status == Status::NoteOff {
            // no pitch detected
            if let Some(last_event) = &self.last_event {
                // end the last note.
                if last_event.status == Status::NoteOn {
                    self.send(&last_event.off_clone());
                }
            }
        }
    }
}
