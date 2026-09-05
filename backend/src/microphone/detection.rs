use serde::Serialize;
use std::f32;

use crate::event::NOTE_NAMES;
use pitch_detection::detector::yin::YINDetector;
use pitch_detection::detector::PitchDetector as PitchDetectorTrait;

/// Snapshot of the detector's public state, used for debug serialization.
///
/// `PitchDetector` itself cannot be serialized or cloned: it owns a
/// `McLeodDetector`, which is neither. This is fine because detection runs on a
/// single dedicated processing thread, so the detector never crosses threads.
#[derive(Clone, Serialize)]
pub struct PitchStats {
    pub level_min: f32,
    pub level_max: f32,
    pub current: String,
    pub current_frequency: f32,
    pub energy: f32,
    pub threshold: f32,
    pub sample_rate: u32,
}

impl PitchStats {
    fn new() -> Self {
        Self {
            level_min: 0f32,
            level_max: -f32::MAX,
            current: String::new(),
            current_frequency: 0.0,
            energy: 0.0,
            threshold: f32::MAX,
            sample_rate: 0,
        }
    }
}

pub struct PitchDetector {
    stats: PitchStats,
    //detector: McLeodDetector<f32>,
    detector: YINDetector<f32>,
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
    pub fn new() -> Self {
        Self {
            stats: PitchStats::new(),
            //detector: McLeodDetector::new(DETECT_WINDOW, DETECT_PADDING),
            detector: YINDetector::new(
                super::hardware::DETECT_WINDOW,
                super::hardware::DETECT_PADDING,
            ),
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
        if self.stats.energy >= self.stats.threshold {
            self.update_pitch(buffer);
        }
        log::trace!(
            "min:{:.3}|curr:{:.3}|max:{:.3} threshold:{:.3} => {:>5} ({5:.1} Hz)",
            self.stats.level_min,
            self.stats.energy,
            self.stats.level_max,
            self.stats.threshold,
            self.stats.current,
            self.stats.current_frequency
        );
    }
    /// Run pitch detection on the current block and store the best note name.
    /// Only called when sound is detected (`energy >= threshold`).
    fn update_pitch(&mut self, buffer: &[f32]) {
        if self.stats.sample_rate == 0 || buffer.len() < super::hardware::DETECT_WINDOW {
            return;
        }
        if let Some(pitch) = self.detector.get_pitch(
            &buffer[..super::hardware::DETECT_WINDOW],
            self.stats.sample_rate as usize,
            super::hardware::POWER_THRESHOLD,
            super::hardware::CLARITY_THRESHOLD,
        ) {
            self.stats.current_frequency = pitch.frequency;
            self.stats.current = freq_to_note_name(pitch.frequency);
        }
    }
    fn compute_threshold(&self) -> f32 {
        self.stats.level_min + (self.stats.level_max - self.stats.level_min) / 3.0
    }
    pub fn on(&self) -> bool {
        self.stats.energy >= self.stats.threshold
    }
    pub fn pitch(&self) -> String {
        self.stats.current.clone()
    }
    pub fn set_sample_rate(&mut self, sample_rate: u32) {
        self.stats.sample_rate = sample_rate;
    }
    pub fn stats(&self) -> PitchStats {
        self.stats.clone()
    }
}

/// Convert a frequency (Hz) into the nearest note name, e.g. "C#4".
fn freq_to_note_name(freq: f32) -> String {
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
    use super::*;

    fn sine_buffer(freq: f32, sample_rate: u32, len: usize) -> Vec<f32> {
        (0..len)
            .map(|i| (2.0 * std::f32::consts::PI * freq * (i as f32 / sample_rate as f32)).sin())
            .collect()
    }

    #[test]
    fn detects_c4() {
        let mut pd = PitchDetector {
            stats: PitchStats {
                level_min: 0.001,
                level_max: 0.1,
                current: String::new(),
                current_frequency: 0.0,
                energy: 0.0,
                threshold: 0.0,
                sample_rate: 48_000,
            },
            detector: YINDetector::new(
                super::super::hardware::DETECT_WINDOW,
                super::super::hardware::DETECT_PADDING,
            ),
        };
        let buffer = sine_buffer(261.63, 48_000, super::super::hardware::DETECT_WINDOW);
        pd.update(&buffer);
        assert!(pd.on());
        assert_eq!(pd.pitch(), "C4");
    }
}
