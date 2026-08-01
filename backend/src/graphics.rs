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

    fn write_and_check(offset: i32, name: &str) {
        let svg = generate(offset);
        std::fs::write(format!("/tmp/{name}.svg"), &svg).expect("should write file");
        let expected = std::fs::read(format!("data/ref/offset/{name}.svg")).expect("should read file");
        assert_eq!(svg, expected);
    }

    #[test]
    fn generate_offset_0() {
        write_and_check(0, "N0");
    }

    #[test]
    fn generate_offset_1() {
        write_and_check(1, "N1");
    }

    #[test]
    fn generate_offset_11() {
        write_and_check(11, "N11");
    }

    #[test]
    fn generate_offset_13() {
        write_and_check(13, "N13");
    }

    #[test]
    fn generate_offset_minus_1() {
        write_and_check(-1, "M1");
    }

    #[test]
    fn generate_offset_minus_3() {
        write_and_check(-3, "M3");
    }
}
