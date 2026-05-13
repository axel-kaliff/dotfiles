use bionify::transform;

fn run(input: &str, ratio: f32) -> String {
    let mut out = Vec::new();
    transform(input, ratio, &mut out).unwrap();
    String::from_utf8(out).unwrap()
}

#[test]
fn empty_input_empty_output() {
    assert_eq!(run("", 0.4), "");
}

#[test]
fn plain_word_gets_bionic_bold() {
    // "Hello" — 5 chars * 0.4 = ceil(2.0) = 2 bold
    assert_eq!(run("Hello", 0.4), "\x1b[1mHe\x1b[22mllo");
}

#[test]
fn whitespace_is_preserved() {
    // "Hi" — 2 * 0.4 = ceil(0.8) = 1
    // "there" — 5 * 0.4 = ceil(2.0) = 2
    assert_eq!(run("Hi there", 0.4), "\x1b[1mH\x1b[22mi \x1b[1mth\x1b[22mere");
}

#[test]
fn ansi_escape_passes_through_verbatim() {
    let result = run("\x1b[31mRed\x1b[0m", 0.4);
    // "Red" — 3 * 0.4 = ceil(1.2) = 2 bold
    assert_eq!(result, "\x1b[31m\x1b[1mRe\x1b[22md\x1b[0m");
}

#[test]
fn truecolor_sgr_preserved() {
    // 24-bit color: \x1b[38;2;R;G;Bm — ansi-parser would truncate this; ours doesn't
    let input = "\x1b[38;2;255;128;0mHello\x1b[0m";
    let result = run(input, 0.4);
    assert!(result.contains("\x1b[38;2;255;128;0m"));
    assert!(result.contains("\x1b[1mHe\x1b[22mllo"));
    assert!(result.ends_with("\x1b[0m"));
}

#[test]
fn osc_hyperlink_preserved() {
    // OSC 8 hyperlink — ESC ] 8 ; ; URL ESC \ text ESC ] 8 ; ; ESC \
    let input = "\x1b]8;;https://example.com\x1b\\click\x1b]8;;\x1b\\";
    let result = run(input, 0.4);
    assert!(result.contains("\x1b]8;;https://example.com\x1b\\"));
    assert!(result.contains("\x1b]8;;\x1b\\"));
    // "click" — 5 * 0.4 = 2 bold
    assert!(result.contains("\x1b[1mcl\x1b[22mick"));
}

#[test]
fn apc_kitty_graphics_preserved() {
    // APC: ESC _ ... ESC \ — used by Kitty graphics protocol
    let input = "before \x1b_Gf=100,a=T,m=1\x1b\\ after";
    let result = run(input, 0.4);
    assert!(result.contains("\x1b_Gf=100,a=T,m=1\x1b\\"));
}

#[test]
fn osc_bel_terminator_preserved() {
    // Some OSC sequences end with BEL (0x07) instead of ST
    let input = "\x1b]0;title\x07rest";
    let result = run(input, 0.4);
    assert!(result.starts_with("\x1b]0;title\x07"));
}

#[test]
fn uses_sgr_22_not_sgr_0_for_bold_close() {
    let result = run("test", 0.4);
    assert!(result.contains("\x1b[22m"));
    // SGR 0 in output would only ever be from input — none here
    assert!(!result.contains("\x1b[0m"));
}

#[test]
fn utf8_word_splits_on_char_boundary() {
    // "café" — 4 chars (c, a, f, é) * 0.4 = ceil(1.6) = 2 bold
    let result = run("café", 0.4);
    assert_eq!(result, "\x1b[1mca\x1b[22mfé");
}

#[test]
fn single_char_word_gets_one_bold_char() {
    // 1 * 0.4 = ceil(0.4) = 1
    assert_eq!(run("a b", 0.4), "\x1b[1ma\x1b[22m \x1b[1mb\x1b[22m");
}

#[test]
fn pure_ansi_input_passes_through() {
    let input = "\x1b[31m\x1b[1m\x1b[0m";
    assert_eq!(run(input, 0.4), input);
}

#[test]
fn multiple_consecutive_whitespace() {
    assert_eq!(run("hi   bye", 0.4), "\x1b[1mh\x1b[22mi   \x1b[1mby\x1b[22me");
}

#[test]
fn newlines_preserved() {
    let result = run("foo\nbar\n", 0.4);
    // "foo" 3*0.4=ceil(1.2)=2, "bar" 3*0.4=2
    assert_eq!(result, "\x1b[1mfo\x1b[22mo\n\x1b[1mba\x1b[22mr\n");
}

#[test]
fn ratio_clamps_to_full_word_at_high_values() {
    // ratio 1.0 → whole word bold
    assert_eq!(run("hi", 1.0), "\x1b[1mhi\x1b[22m");
}

#[test]
fn already_bold_text_passes_through_untouched() {
    // mdcat heading: \x1b[1mBoldHeading\x1b[0m
    // External bold is on — bionify must not nest another bold/22 that would
    // cancel the heading bold mid-word.
    let result = run("\x1b[1mBoldHeading\x1b[0m", 0.4);
    assert_eq!(result, "\x1b[1mBoldHeading\x1b[0m");
}

#[test]
fn bold_then_unbold_then_bionic() {
    // \x1b[1mbold\x1b[22m word — "bold" stays untouched, "word" gets bionic
    let result = run("\x1b[1mbold\x1b[22m word", 0.4);
    assert!(result.starts_with("\x1b[1mbold\x1b[22m"));
    assert!(result.contains("\x1b[1mwo\x1b[22mrd"));
}

#[test]
fn sgr_0_reset_clears_external_bold_state() {
    let result = run("\x1b[1mbold\x1b[0m word", 0.4);
    assert!(result.starts_with("\x1b[1mbold\x1b[0m"));
    assert!(result.contains("\x1b[1mwo\x1b[22mrd"));
}

#[test]
fn empty_sgr_resets_like_sgr_0() {
    // \x1b[m is equivalent to \x1b[0m
    let result = run("\x1b[1mbold\x1b[m word", 0.4);
    assert!(result.contains("\x1b[1mwo\x1b[22mrd"));
}

#[test]
fn bold_plus_color_combined_sgr_tracked() {
    // \x1b[1;34m sets bold + blue in one CSI
    let result = run("\x1b[1;34mBlueBold\x1b[0m plain", 0.4);
    // Bold flag is set by the combined CSI — bionic should skip "BlueBold"
    assert!(result.contains("\x1b[1;34mBlueBold\x1b[0m"));
    assert!(result.contains("\x1b[1mpl\x1b[22main"));
}

#[test]
fn truecolor_word_layered_with_bionic() {
    // Regression: bieye-style mangling — verify ours doesn't
    let input = "\x1b[38;2;100;200;50mGreenWord\x1b[0m end";
    let result = run(input, 0.4);
    // The color escape must come first, then bold-on, then chars, then bold-off,
    // and the SGR 0 must still terminate at the end of the colored word.
    assert!(result.starts_with("\x1b[38;2;100;200;50m\x1b[1m"));
    assert!(result.contains("\x1b[22m"));
    assert!(result.contains("\x1b[0m"));
}
