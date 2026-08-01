use backend::event::Event;

#[test]
fn svg_matches_reference() {
    for note in ["C4", "D4", "E4"] {
        let event = Event::from_note(note).expect("valid note name");
        std::fs::write(format!("/tmp/{}.svg", note), &event.svg).expect("should write file");
        let expected = std::fs::read(format!("data/ref/notes/{}.svg", note))
            .expect("reference file should exist");
        assert_eq!(event.svg, expected);
    }
}
