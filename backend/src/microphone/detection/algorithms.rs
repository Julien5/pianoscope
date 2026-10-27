#[derive(Clone)]
pub struct Estimate {
    pub frequency: f32,
    pub confidence: f32,
    pub annotation: Option<String>,
}

#[derive(Clone)]
pub struct Estimates {
    // (confidence, frequency)
    estimates: Vec<Estimate>,
}

impl Estimates {
    pub fn print(&self) {
        if self.estimates.is_empty() {
            log::trace!("no estimate");
        }
        for (index, estimate) in self.estimates.iter().enumerate() {
            let note = super::freq_to_note_name(estimate.frequency);
            log::trace!(
                "{}. estimate: {:.1} ({:>3}) confidence: {:.2} notes:{:?}",
                index + 1,
                estimate.frequency,
                note,
                estimate.confidence,
                estimate.annotation
            );
        }
    }
    pub fn best(&self) -> Option<Estimate> {
        let mut sorted = self.estimates.clone();
        sorted.sort_by(|ea, eb| ea.confidence.total_cmp(&eb.confidence));
        if let Some(e) = sorted.last() {
            return Some(e.clone());
        }
        None
    }

    pub fn is_empty(&self) -> bool {
        self.estimates.is_empty()
    }
}

use pitch_detection::detector::PitchDetector as PitchDetectorTrait;

use crate::microphone::processor::BlockProcessorParameters;

pub struct McLeodDetector {
    detector: pitch_detection::detector::mcleod::McLeodDetector<f32>,
    parameters: BlockProcessorParameters,
}

impl McLeodDetector {
    pub fn new(parameters: &BlockProcessorParameters) -> Self {
        log::trace!("make McLeod detector");
        Self {
            detector: pitch_detection::detector::mcleod::McLeodDetector::new(
                parameters.window_len,
                parameters.window_len / 2,
            ),
            parameters: parameters.clone(),
        }
    }

    pub fn process(&mut self, buffer: &[f32]) -> Estimates {
        let empty = Estimates {
            estimates: Vec::new(),
        };
        let mut ret = Vec::new();
        if buffer.len() < self.parameters.window_len {
            return empty;
        } else if buffer.len() > self.parameters.window_len {
        }
        debug_assert_eq!(buffer.len(), self.parameters.window_len);
        if let Some(pitch) = self.detector.get_pitch(
            &buffer,
            self.parameters.sample_rate as usize,
            0.0, // power detect is upfront
            0.6, // clarity
        ) {
            ret.push(Estimate {
                frequency: pitch.frequency,
                confidence: 0.6,
                annotation: None,
            });
        }
        Estimates { estimates: ret }
    }
}
