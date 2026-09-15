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
    pub estimates: Vec<Estimate>,
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
}

pub trait Detector {
    fn process(&mut self, block: &[f32]) -> Estimates;
}

pub fn make_detector(parameters: &PitchRecognizerParameters) -> Box<dyn Detector> {
    match parameters.algorithm {
        crate::microphone::PitchRecognizerAlgorithm::PYIN => {
            Box::new(PYInDetector::new(parameters))
        }
        crate::microphone::PitchRecognizerAlgorithm::McLeod => {
            Box::new(McLeodDetector::new(parameters))
        }
        crate::microphone::PitchRecognizerAlgorithm::YIN => Box::new(YinDetector::new(parameters)),
        crate::microphone::PitchRecognizerAlgorithm::Swipe => {
            Box::new(SwipeDetector::new(parameters))
        }
        crate::microphone::PitchRecognizerAlgorithm::AutoCorrelation => {
            Box::new(AutoCorrelationDetector::new(parameters))
        }
        crate::microphone::PitchRecognizerAlgorithm::Kord => {
            Box::new(KordDetector::new(parameters))
        }
    }
}

pub struct PYInDetector {
    tracker: pitch_core::PitchTracker,
}

impl PYInDetector {
    pub fn new(parameters: &PitchRecognizerParameters) -> Self {
        log::trace!("make PYIN detector");
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

pub struct SwipeDetector {
    tracker: pitch_core::PitchTracker,
}

impl SwipeDetector {
    pub fn new(parameters: &PitchRecognizerParameters) -> Self {
        log::trace!("make Swipe detector");
        let est = pitch_core::SwipeEstimator::new().unwrap();
        let tracker = pitch_core::PitchTracker::new(est, parameters.sample_rate, 1024)
            .expect("could not build tracker");
        Self { tracker }
    }
}

impl Detector for SwipeDetector {
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

use pitch_detection::detector::mcleod::McLeodDetector as McLeod;
use pitch_detection::detector::PitchDetector as PitchDetectorTrait;

pub struct McLeodDetector {
    detector: McLeod<f32>,
    parameters: PitchRecognizerParameters,
}

impl McLeodDetector {
    pub fn new(parameters: &PitchRecognizerParameters) -> Self {
        log::trace!("make McLeod detector");
        Self {
            detector: McLeod::new(parameters.window_len, parameters.window_len / 2),
            parameters: parameters.clone(),
        }
    }
}

impl Detector for McLeodDetector {
    fn process(&mut self, buffer: &[f32]) -> Estimates {
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

use pitch_detection::detector::yin::YINDetector as YIN;

pub struct YinDetector {
    detector: YIN<f32>,
    parameters: PitchRecognizerParameters,
}

impl YinDetector {
    pub fn new(parameters: &PitchRecognizerParameters) -> Self {
        log::trace!("make YIN detector");
        Self {
            detector: YIN::new(parameters.window_len, parameters.window_len / 2),
            parameters: parameters.clone(),
        }
    }
}

impl Detector for YinDetector {
    fn process(&mut self, buffer: &[f32]) -> Estimates {
        let mut ret = Vec::new();
        if buffer.len() < self.parameters.window_len {
            return Estimates {
                estimates: Vec::new(),
            };
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
                confidence: 0.75,
                annotation: None,
            });
        }
        Estimates { estimates: ret }
    }
}

use pitch_detection::detector::autocorrelation::AutocorrelationDetector as AutoCorrelation;

pub struct AutoCorrelationDetector {
    detector: AutoCorrelation<f32>,
    parameters: PitchRecognizerParameters,
}

impl AutoCorrelationDetector {
    pub fn new(parameters: &PitchRecognizerParameters) -> Self {
        log::trace!("make AutoCorrelationDetector");
        Self {
            detector: AutoCorrelation::new(parameters.window_len, parameters.window_len / 2),
            parameters: parameters.clone(),
        }
    }
}

impl Detector for AutoCorrelationDetector {
    fn process(&mut self, buffer: &[f32]) -> Estimates {
        let mut ret = Vec::new();
        if buffer.len() < self.parameters.window_len {
            return Estimates {
                estimates: Vec::new(),
            };
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
                confidence: 0.75,
                annotation: None,
            });
        }
        Estimates { estimates: ret }
    }
}

use crate::microphone::detection::kord;

pub struct KordDetector {
    parameters: PitchRecognizerParameters,
    buffer: Vec<f32>,
}

impl KordDetector {
    pub fn new(parameters: &PitchRecognizerParameters) -> Self {
        log::trace!("make KordDetector");
        Self {
            parameters: parameters.clone(),
            buffer: Vec::with_capacity(parameters.sample_rate as usize),
        }
    }
}

impl Detector for KordDetector {
    fn process(&mut self, buffer: &[f32]) -> Estimates {
        for &s in buffer {
            self.buffer.push(s);
        }
        let capacity = self.parameters.sample_rate as usize;
        if self.buffer.len() > capacity {
            let excess = self.buffer.len() - capacity;
            let _ = self.buffer.drain(..excess);
        }
        if self.buffer.len() < capacity {
            return Estimates {
                estimates: Vec::new(),
            };
        }
        let notes = kord::analyze(&self.buffer, 1);
        if notes.is_empty() {
            return Estimates {
                estimates: Vec::new(),
            };
        }
        let mut max_magnitude = 0.0;
        for (_, magnitude) in &notes {
            if *magnitude > max_magnitude {
                max_magnitude = *magnitude;
            }
        }
        let estimates = notes
            .iter()
            .map(|(frequency, magnitude)| Estimate {
                frequency: *frequency,
                confidence: if max_magnitude > 0.0 {
                    *magnitude / max_magnitude
                } else {
                    0.0
                },
                annotation: None,
            })
            .collect::<Vec<_>>();
        Estimates { estimates }
    }
}
