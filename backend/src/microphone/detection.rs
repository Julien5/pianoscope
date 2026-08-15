use serde::Serialize;
use std::f32;

#[derive(Clone, Serialize)]
pub struct PitchDetector {
    level_min: f32,
    level_max: f32,
    current: String,
    energy: f32,
    threshold: f32,
    sample_rate: u32,
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
            level_min: f32::MAX,
            level_max: -f32::MAX,
            current: String::new(),
            energy: 0.0,
            threshold: f32::MAX,
            sample_rate: 0,
        }
    }
    pub fn update(&mut self, buffer: &[f32]) {
        self.energy = compute_energy(buffer);

        if self.energy < self.level_min {
            self.level_min = self.energy;
        }
        if self.energy > self.level_max {
            self.level_max = self.energy;
        }
        let alpha = 0.01;
        self.level_max = (1.0 - alpha) * self.level_max + alpha * self.energy;
        self.level_min = (1.0 - alpha) * self.level_min + alpha * self.energy;
        self.threshold = self.level_min + (self.level_max - self.level_min) / 3.0;
        log::trace!(
            "run threshold recognizer: {:.5} | {:.5} | {:.5}",
            self.level_min,
            self.energy,
            self.level_max,
        );
        if self.energy >= self.threshold {
            self.current = format!("C4");
        } else {
        }
    }
    pub fn on(&self) -> bool {
        self.energy >= self.threshold
    }
    pub fn pitch(&self) -> String {
        self.current.clone()
    }
    pub fn set_sample_rate(&mut self, sample_rate: u32) {
        self.sample_rate = sample_rate;
    }
}
