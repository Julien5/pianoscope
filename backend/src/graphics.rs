pub fn generate(offset: i32) -> Vec<u8> {
    let template = include_bytes!("../data/templates/note.svg");
    let template = std::str::from_utf8(template).unwrap();
    let y = offset as f64 * 0.875;
    template.replacen("{y}", &y.to_string(), 1).into_bytes()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn generate_offset_0() {
        let expected = include_bytes!("../data/ref/N0.svg");
        assert_eq!(generate(0), expected.to_vec());
    }

    #[test]
    fn generate_offset_1() {
        let expected = include_bytes!("../data/ref/N1.svg");
        assert_eq!(generate(1), expected.to_vec());
    }
}
