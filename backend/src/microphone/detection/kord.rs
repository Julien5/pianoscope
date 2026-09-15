// source: https://github.com/twitchax/kord

use std::ops::Deref;
use std::sync::LazyLock;

use rustfft::{
    num_complex::{Complex, ComplexFloat},
    FftPlanner,
};

#[derive(PartialEq, Eq, Clone, Copy)]
pub struct Note {
    pub pitch: u8,
    pub octave: u8,
}

impl Note {
    pub fn frequency(&self) -> f32 {
        BASE_FREQUENCIES[self.pitch as usize] * 2.0_f32.powf(self.octave as f32)
    }
}

const BASE_FREQUENCIES: &[f32; 12] = &[
    16.35, 17.32, 18.35, 19.45, 20.60, 21.83, 23.12, 24.50, 25.96, 27.50, 29.14, 30.87,
];

const FIFTH_INDEX: &[u8; 12] = &[22, 17, 24, 19, 26, 21, 16, 23, 18, 25, 20, 27];

const HARMONIC_SERIES: &[(i8, u8); 13] = &[
    (0, 1),
    (1, 1),
    (0, 2),
    (4, 2),
    (1, 2),
    (-2, 2),
    (2, 3),
    (4, 3),
    (6, 3),
    (1, 3),
    (-4, 3),
    (-2, 3),
    (5, 3),
];

static ALL_NOTES_WITH_FREQUENCY: LazyLock<Vec<(Note, f32)>> = LazyLock::new(|| {
    let mut notes = Vec::with_capacity(192);
    for octave in 0..16 {
        for pitch in 0..12 {
            let note = Note {
                pitch: pitch as u8,
                octave: octave as u8,
            };
            notes.push((note, note.frequency()));
        }
    }
    notes
});

/// Analyze audio and return (frequency, magnitude) pairs for the detected notes,
/// sorted from strongest to weakest.  Empty on degenerate input.
pub fn analyze(data: &[f32], length_in_seconds: u8) -> Vec<(f32, f32)> {
    if length_in_seconds < 1 {
        return Vec::new();
    }
    if data.iter().any(|&n| n.is_nan()) {
        return Vec::new();
    }
    if data.len() % length_in_seconds as usize != 0 {
        return Vec::new();
    }

    let frequency_space = get_frequency_space(data, length_in_seconds);
    let smoothed_frequency_space =
        get_smoothed_frequency_space(&frequency_space, length_in_seconds);
    let peak_space = translate_frequency_space_to_peak_space(&smoothed_frequency_space);
    let peak_best_notes = get_likely_notes_from_peak_space(&peak_space, 0.1);
    let best_notes = reduce_notes_by_harmonic_series(&peak_best_notes, 0.1);

    best_notes
        .into_iter()
        .map(|(note, magnitude)| (note.frequency(), magnitude))
        .collect::<Vec<_>>()
}

fn get_frequency_space(data: &[f32], length_in_seconds: u8) -> Vec<(f32, f32)> {
    let mut planner = FftPlanner::<f32>::new();
    let fft = planner.plan_fft_forward(data.len());

    let mut buffer = data
        .iter()
        .map(|&n| Complex::new(n, 0.0))
        .collect::<Vec<_>>();
    fft.process(&mut buffer);

    buffer
        .into_iter()
        .enumerate()
        .map(|(k, d)| (k as f32 / length_in_seconds as f32, d.abs()))
        .collect::<Vec<_>>()
}

fn get_smoothed_frequency_space(
    frequency_space: &[(f32, f32)],
    length_in_seconds: u8,
) -> Vec<(f32, f32)> {
    let mut smoothed_frequency_space = Vec::new();
    let size = length_in_seconds as usize;

    let mut k = 0;
    while k + size <= frequency_space.len() {
        let chunk = &frequency_space[k..k + size];
        let average_frequency = chunk.iter().map(|(f, _)| *f).sum::<f32>() / size as f32;
        let average_magnitude = chunk.iter().map(|(_, m)| *m).sum::<f32>() / size as f32;
        smoothed_frequency_space.push((average_frequency, average_magnitude));
        k += size;
    }

    smoothed_frequency_space
}

fn translate_frequency_space_to_peak_space(frequency_space: &[(f32, f32)]) -> Vec<(f32, f32)> {
    let magic_window_number = 50f32;
    let min_index = 50;
    let max_index = 8_000;

    let mut peak_space = frequency_space.to_vec();

    let mut last_k = min_index;
    let mut k = min_index;
    while k < max_index {
        let window_size = (frequency_space[k].0 / magic_window_number) as usize;
        let max_end = (k + window_size).min(frequency_space.len());

        let mut max_in_window = 0.0;
        for j in k..max_end {
            if frequency_space[j].1 > max_in_window {
                max_in_window = frequency_space[j].1;
            }
        }

        let mut next = 0;
        for j in k..max_end {
            if frequency_space[j].1 == max_in_window {
                peak_space[j] = (peak_space[j].0, peak_space[j].1);
                next = j;
            } else {
                peak_space[j] = (peak_space[j].0, 0.0);
            }
        }

        k = next;

        if last_k == k {
            k += 1;
        }

        last_k = k;
    }

    let skip = min_index;
    let take = max_index - min_index;

    let end = (skip + take).min(peak_space.len());
    for k in skip..end {
        let window_size = 3;
        let average_right_derivative = ((frequency_space
            [(k + window_size).min(frequency_space.len() - 1)]
        .1 - frequency_space[k].1)
            / window_size as f32)
            .abs();
        let average_left_derivative = ((frequency_space[k].1
            - frequency_space[(k - window_size).max(0)].1)
            / window_size as f32)
            .abs();
        let average_derivative = (average_right_derivative + average_left_derivative) / 2f32;

        if average_derivative / peak_space[k].1 < 0.1 {
            peak_space[k].1 = 0.0;
        }
    }

    peak_space
        .into_iter()
        .skip(min_index)
        .take(max_index - min_index)
        .collect::<Vec<_>>()
}

fn get_likely_notes_from_peak_space(peak_space: &[(f32, f32)], cutoff: f32) -> Vec<(Note, f32)> {
    let mut peak_space = peak_space
        .iter()
        .filter(|(_, m)| *m > 0.1)
        .copied()
        .collect::<Vec<_>>();
    peak_space.sort_by(|a, b| b.1.total_cmp(&a.1));

    if peak_space.is_empty() {
        return Vec::new();
    }

    let max_power = peak_space[0].1;
    let peak_space = peak_space
        .into_iter()
        .filter(|(_, m)| *m > max_power * cutoff)
        .collect::<Vec<_>>();

    let mut candidates = Vec::new();

    for (frequency, magnitude) in &peak_space {
        if let Some(index) = binary_search_closest(ALL_NOTES_WITH_FREQUENCY.deref(), *frequency) {
            let note = ALL_NOTES_WITH_FREQUENCY.deref()[index].0;
            let mut found = false;
            for (existing_note, accumulated) in candidates.iter_mut() {
                if *existing_note == note {
                    *accumulated += *magnitude;
                    found = true;
                    break;
                }
            }
            if !found {
                candidates.push((note, *magnitude));
            }
        }
    }

    candidates
}

fn reduce_notes_by_harmonic_series(notes: &[(Note, f32)], cutoff: f32) -> Vec<(Note, f32)> {
    let mut working_set = notes.to_vec();
    working_set.sort_by(|a, b| a.0.frequency().total_cmp(&b.0.frequency()));

    let mut k = 0;
    while k < working_set.len() {
        let note = working_set[k].0;
        let harmonics = primary_harmonic_series(&note);

        let mut j = k + 1;
        while j < working_set.len() {
            let other_note = working_set[j].0;

            for harmonic in &harmonics {
                if harmonic.frequency() == other_note.frequency() {
                    working_set[k].1 += working_set[j].1;
                    working_set.remove(j);
                    j -= 1;
                    break;
                }
            }

            j += 1;
        }

        k += 1;
    }

    working_set.sort_by(|a, b| b.1.total_cmp(&a.1));

    if working_set.is_empty() {
        return Vec::new();
    }

    let cutoff = working_set[0].1 * cutoff;
    working_set.retain(|(_, magnitude)| *magnitude > cutoff);

    working_set
}

fn primary_harmonic_series(note: &Note) -> Vec<Note> {
    HARMONIC_SERIES
        .iter()
        .map(|&(fifths, octave)| harmonic_add(note, fifths, octave))
        .collect::<Vec<_>>()
}

fn harmonic_add(note: &Note, fifths: i8, interval_octave: u8) -> Note {
    let index = FIFTH_INDEX[note.pitch as usize] as i32 + fifths as i32;

    let new_pitch = pitch_class_of_fifth_index(index);

    let wrapping_octave = if new_pitch < note.pitch { 1 } else { 0 };

    let special_octave = if index == 15 || index == 8 || index == 1 || index == 3 {
        1
    } else if index == 34 || index == 41 || index == 48 || index == 46 {
        -1
    } else {
        0
    };

    Note {
        pitch: new_pitch,
        octave: (note.octave as i32 + interval_octave as i32 + wrapping_octave + special_octave)
            as u8,
    }
}

fn pitch_class_of_fifth_index(index: i32) -> u8 {
    (7 * (index - 22)).rem_euclid(12) as u8
}

fn binary_search_closest(array: &[(Note, f32)], target: f32) -> Option<usize> {
    let mut low = 0;
    let mut high = array.len();

    while low < high {
        let mid = (low + high) / 2;

        if array[mid].1 < target {
            low = mid + 1;
        } else {
            high = mid;
        }
    }

    if low == 0 || low == array.len() {
        return None;
    }

    let low_index = low - 1;
    let high_index = low;
    let low_value = array[low_index].1;
    let high_value = array[high_index].1;

    if (high_value - target).abs() < (target - low_value).abs() {
        Some(high_index)
    } else {
        Some(low_index)
    }
}
