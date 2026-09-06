use crate::microphone::PitchRecognizerParameters;

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
        if let Some(e) = self.estimates.first() {
            return Some(e.clone());
        }
        None
    }
}

pub trait Detector {
    fn process(&mut self, block: &[f32]) -> Estimates;
}

pub fn make_detector(parameters: &PitchRecognizerParameters) -> Box<dyn Detector> {
    match parameters._algorithm {
        crate::microphone::PitchRecognizerAlgorithm::PYIN => {
            Box::new(PYInDetector::new(parameters))
        }
        crate::microphone::PitchRecognizerAlgorithm::McLeod => {
            Box::new(PYInDetector::new(parameters))
        }
    }
}

pub struct PYInDetector {
    tracker: pitch_core::PitchTracker,
}

impl PYInDetector {
    pub fn new(parameters: &PitchRecognizerParameters) -> Self {
        let est = pitch_core::PyinEstimator::new().unwrap();
        let tracker = pitch_core::PitchTracker::new(est, parameters.sample_rate, 1024)
            .expect("could not build tracker");
        Self { tracker }
    }
}

impl Detector for PYInDetector {
    fn process(&mut self, buffer: &[f32]) -> Estimates {
        let mut ret = Vec::new();
        for estimate in self.tracker.process(&buffer).unwrap() {
            ret.push(Estimate {
                frequency: estimate.pitch_hz,
                confidence: estimate.confidence,
                annotation: Some(format!("prelim:{}", estimate.is_preliminary)),
            });
        }
        Estimates { estimates: ret }
    }
}
