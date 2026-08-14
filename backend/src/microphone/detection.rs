use std::f32;

pub struct PitchDetector {
    threshold: f32,
    current: String,
}

fn compute_energy(samples: &[f32]) -> f64 {
    if samples.is_empty() {
        return 0.0;
    }
    //samples.iter().map(|x| x.abs()).fold(0f32 / 0f32, f32::max) as f64
    let sum_sq: f64 = samples.iter().map(|&s| (s as f64) * (s as f64)).sum();
    (sum_sq / samples.len() as f64).sqrt()
}

impl PitchDetector {
    pub fn new() -> Self {
        Self {
            threshold: f32::MAX,
            current: String::new(),
        }
    }
    pub fn update(&mut self, buffer: &[f32]) {
        // TODO: update threshold
        // if sound, compute pitch
        let energy = compute_energy(buffer);
        const ENERGY_THRESHOLD: f64 = 0.01;

        log::trace!(
            "run threshold recognizer: {:.5} / {:.5}",
            energy,
            ENERGY_THRESHOLD
        );
        if energy >= ENERGY_THRESHOLD {
            self.current = format!("C4");
        } else {
            self.current.clear();
        }
    }
    pub fn pitch(&self) -> String {
        self.current.clone()
    }
}
