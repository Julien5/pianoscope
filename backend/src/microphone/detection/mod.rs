pub mod algorithms;

use serde::Serialize;
use std::f32;

use crate::{
    event::NOTE_NAMES,
    microphone::{detection::algorithms::Detector, PitchRecognizerParameters},
};

#[derive(Clone, Debug, Serialize)]
pub struct PitchStats {
    pub level_min: f32,
    pub level_max: f32,
    pub current_note: String,
    pub current_frequency: f32,
    pub energy: f32,
    pub threshold: f32,
    pub sample_rate: u32,
}

impl PitchStats {
    fn new(sample_rate: u32) -> Self {
        Self {
            level_min: 0f32,
            level_max: -f32::MAX,
            current_note: String::new(),
            current_frequency: 0.0,
            energy: 0.0,
            threshold: f32::MAX,
            sample_rate,
        }
    }
    pub fn velocity(&self) -> u8 {
        debug_assert!(self.threshold >= self.level_min);
        if self.energy <= self.threshold {
            return 0u8;
        }
        debug_assert!(self.threshold <= self.energy && self.energy <= self.level_max);
        let scaled =
            1.0 + 126.0 * (self.energy - self.threshold) / (self.level_max - self.threshold);
        debug_assert!(0.9 <= scaled && scaled <= 127.1, "scaled={}", scaled);
        return scaled.round() as u8;
    }
}

pub struct PitchDetector {
    stats: PitchStats,
    detector: Box<dyn Detector>,
}

fn compute_energy(samples: &[f32]) -> f32 {
    if samples.is_empty() {
        return 0.0;
    }
    //samples.iter().map(|x| x.abs()).fold(0f32 / 0f32, f32::max) as f64
    let sum_sq: f32 = samples.iter().map(|&s| s * s).sum();
    (sum_sq / (samples.len() as f32)).sqrt()
}

impl PitchDetector {
    pub fn new(parameters: &PitchRecognizerParameters) -> Self {
        Self {
            stats: PitchStats::new(parameters.sample_rate),
            detector: algorithms::make_detector(parameters),
        }
    }

    pub fn update(&mut self, buffer: &[f32]) {
        self.stats.energy = compute_energy(buffer);
        if self.stats.energy < self.stats.level_min {
            self.stats.level_min = self.stats.energy;
        }
        if self.stats.energy > self.stats.level_max {
            self.stats.level_max = self.stats.energy;
        }
        let alpha = 0.01;
        self.stats.level_max = (1.0 - alpha) * self.stats.level_max + alpha * self.stats.energy;
        self.stats.level_min = (1.0 - alpha) * self.stats.level_min + alpha * self.stats.energy;
        self.stats.threshold = self.compute_threshold();
        // zero the current estimate
        self.stats.current_frequency = 0.0;
        self.stats.current_note = String::new();
        if self.stats.energy >= self.stats.threshold {
            self.update_pitch(buffer);
        }
        /*
        log::trace!(
            "min:{:.3}|curr:{:.3}|max:{:.3} threshold:{:.3} => {:>5} ({5:.1} Hz)",
            self.stats.level_min,
            self.stats.energy,
            self.stats.level_max,
            self.stats.threshold,
            self.stats.current,
            self.stats.current_frequency
        );*/
    }
    /// Run pitch detection on the current block and store the best note name.
    /// Only called when sound is detected (`energy >= threshold`).
    fn update_pitch(&mut self, buffer: &[f32]) {
        debug_assert!(self.stats.sample_rate != 0);
        let estimates = self.detector.process(&buffer);
        estimates.print();
        if let Some(best) = estimates.best() {
            self.stats.current_frequency = best.frequency;
            self.stats.current_note = freq_to_note_name(best.frequency);
        } else {
            debug_assert!(estimates.estimates.is_empty());
        }
    }
    fn compute_threshold(&self) -> f32 {
        self.stats.level_min + (self.stats.level_max - self.stats.level_min) / 6.0
    }
    pub fn on(&self) -> bool {
        self.stats.energy >= self.stats.threshold
    }
    pub fn pitch(&self) -> String {
        self.stats.current_note.clone()
    }
    pub fn stats(&self) -> PitchStats {
        self.stats.clone()
    }
}

/// Convert a frequency (Hz) into the nearest note name, e.g. "C#4".
pub fn freq_to_note_name(freq: f32) -> String {
    if !freq.is_finite() || freq <= 0.0 {
        return String::new();
    }
    let midi = (69.0 + 12.0 * (freq / 440.0).log2()).round() as i32;
    let midi = midi.clamp(0, 127);
    let note_idx = (midi % 12) as usize;
    let octave = midi / 12 - 1;
    format!("{}{}", NOTE_NAMES[note_idx], octave)
}

#[cfg(test)]
mod tests {
    use std::collections::BTreeMap;

    use super::*;

    fn sine_buffer(freq: f32, sample_rate: u32, len: usize) -> Vec<f32> {
        (0..len)
            .map(|i| (2.0 * std::f32::consts::PI * freq * (i as f32 / sample_rate as f32)).sin())
            .collect()
    }

    #[test]
    fn detects_c4() {
        let _ = env_logger::try_init();
        let sample_rate = 48_000;
        let signal_length = (sample_rate / 2) as usize; //  1 sec
        let window_len = signal_length;
        let algorithms = vec![
            PitchRecognizerParameters::new_mcleod(sample_rate, window_len),
            PitchRecognizerParameters::new_pyin(sample_rate, window_len),
            PitchRecognizerParameters::new_swipe(sample_rate, window_len),
            PitchRecognizerParameters::new_yin(sample_rate, window_len),
        ];
        let table = [
            (32.7, "C1"),
            (34.65, "C#1"),
            (36.71, "D1"),
            (65.4, "C2"),
            (261.63, "C4"),
        ];
        let mut results = BTreeMap::new();
        for (freq, note) in table {
            log::trace!("test: {} {}", freq, note);
            let signal = sine_buffer(freq, sample_rate, signal_length);
            for algorithm in &algorithms {
                log::trace!("testing {:?}", algorithm.algorithm);
                let mut pd = PitchDetector::new(&algorithm);
                pd.update(&signal);
                assert!(pd.on());
                let key = format!("{:?}|{}", algorithm.algorithm, note);
                results.insert(key, pd.pitch() == note);
            }
        }
        let mut good = true;
        for (key, ok) in results {
            log::trace!("{} => {}", key, ok);
            if !ok {
                good = false;
            }
        }
        debug_assert!(good);
    }
}
