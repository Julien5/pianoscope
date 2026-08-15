use serde::Serialize;
use std::f32;

#[derive(Clone, Serialize)]
pub struct PitchDetector {
    threshold: f32,
    current: String,
    energy: f64,
    sample_rate: u32,
}

fn compute_energy(samples: &[f32]) -> f64 {
    if samples.is_empty() {
        return 0.0;
    }
    //samples.iter().map(|x| x.abs()).fold(0f32 / 0f32, f32::max) as f64
    let sum_sq: f64 = samples.iter().map(|&s| (s as f64) * (s as f64)).sum();
    (sum_sq / samples.len() as f64).sqrt()
}

const ENERGY_THRESHOLD: f64 = 0.01;

impl PitchDetector {
    pub fn new() -> Self {
        Self {
            threshold: ENERGY_THRESHOLD as f32,
            current: String::new(),
            energy: 0.0,
            sample_rate: 0,
        }
    }
    pub fn update(&mut self, buffer: &[f32]) {
        // TODO: update threshold
        // if sound, compute pitch
        self.energy = compute_energy(buffer);

        log::trace!(
            "run threshold recognizer: {:.5} / {:.5}",
            self.energy,
            ENERGY_THRESHOLD
        );
        if self.energy >= ENERGY_THRESHOLD {
            self.current = format!("C4");
        } else {
        }
    }
    pub fn on(&self) -> bool {
        self.energy >= ENERGY_THRESHOLD
    }
    pub fn pitch(&self) -> String {
        self.current.clone()
    }
    pub fn set_sample_rate(&mut self, sample_rate: u32) {
        self.sample_rate = sample_rate;
    }
}
