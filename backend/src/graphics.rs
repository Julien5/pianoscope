pub fn generate(offset: i32) -> String {
    let template = include_bytes!("../data/templates/note.svg");
    let template = std::str::from_utf8(template).unwrap();
    let y = offset as f64 * 0.875;
    template.replacen("{y}", &y.to_string(), 1)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn generate_offset_0() {
        let expected = include_str!("../data/ref/N0.svg");
        assert_eq!(generate(0), expected);
    }

    #[test]
    fn generate_offset_1() {
        let expected = include_str!("../data/ref/N1.svg");
        assert_eq!(generate(1), expected);
    }
}
