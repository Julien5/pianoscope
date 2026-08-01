const LEDGER_BELOW: &[i32] = &[11, 13, 15];
const LEDGER_ABOVE: &[i32] = &[-1, -3, -5];

pub fn generate(offset: i32) -> Vec<u8> {
    let template = include_bytes!("../data/templates/note.svg");
    let template = std::str::from_utf8(template).unwrap();
    let y = offset as f64 * 0.875;

    let mut svg = template.replace("{y}", &y.to_string());
    for (i, s) in LEDGER_BELOW.iter().enumerate() {
        let visible = offset >= *s;
        svg = svg.replace(&format!("{{b{i}}}"), if visible { "inline" } else { "none" });
    }
    for (i, s) in LEDGER_ABOVE.iter().enumerate() {
        let visible = offset <= *s;
        svg = svg.replace(&format!("{{a{i}}}"), if visible { "inline" } else { "none" });
    }
    svg.into_bytes()
}

pub fn offset_for_midi(note: u8) -> i32 {
    46 - ((7 * note as i32 + 1) / 12)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn generate_offset_0() {
        let expected = include_bytes!("../data/ref/offset/N0.svg");
        assert_eq!(generate(0), expected.to_vec());
    }

    #[test]
    fn generate_offset_1() {
        let expected = include_bytes!("../data/ref/offset/N1.svg");
        assert_eq!(generate(1), expected.to_vec());
    }

    #[test]
    fn generate_offset_11() {
        let expected = include_bytes!("../data/ref/offset/N11.svg");
        assert_eq!(generate(11), expected.to_vec());
    }

    #[test]
    fn generate_offset_13() {
        let expected = include_bytes!("../data/ref/offset/N13.svg");
        assert_eq!(generate(13), expected.to_vec());
    }

    #[test]
    fn generate_offset_minus_1() {
        let expected = include_bytes!("../data/ref/offset/M1.svg");
        assert_eq!(generate(-1), expected.to_vec());
    }

    #[test]
    fn generate_offset_minus_3() {
        let expected = include_bytes!("../data/ref/offset/M3.svg");
        assert_eq!(generate(-3), expected.to_vec());
    }
}
