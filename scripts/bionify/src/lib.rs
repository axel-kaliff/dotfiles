//! ANSI-aware bionic reading transform.
//!
//! Scans the input byte stream into runs of escape sequences (passed through
//! verbatim) and runs of plain text (each word gets its leading portion bolded
//! via SGR 1/22). Tracks whether bold is already set by an upstream SGR so
//! already-bold runs (e.g. mdcat headings) pass through unmodified instead of
//! getting their bold cancelled mid-word.
//!
//! SGR 22 (normal intensity) is used instead of SGR 0 (reset all) so existing
//! color/style state survives the bold-off marker — that's the whole point.

use std::io::{self, Write};

const ESC: u8 = 0x1b;
const BEL: u8 = 0x07;
const BOLD_ON: &[u8] = b"\x1b[1m";
const BOLD_OFF: &[u8] = b"\x1b[22m";

pub fn transform<W: Write>(input: &str, ratio: f32, out: &mut W) -> io::Result<()> {
    let bytes = input.as_bytes();
    let mut i = 0;
    let mut external_bold = false;
    while i < bytes.len() {
        if bytes[i] == ESC {
            let end = find_escape_end(bytes, i);
            let seq = &bytes[i..end];
            update_bold_state(seq, &mut external_bold);
            out.write_all(seq)?;
            i = end;
        } else {
            let end = bytes[i..]
                .iter()
                .position(|&b| b == ESC)
                .map(|p| i + p)
                .unwrap_or(bytes.len());
            // ESC (0x1b) is ASCII, so it never appears inside a UTF-8 multi-byte
            // sequence — slicing as &str at ESC boundaries is safe.
            bionic_text(&input[i..end], ratio, external_bold, out)?;
            i = end;
        }
    }
    Ok(())
}

/// Update `external_bold` based on an SGR escape sequence. No-op for any
/// sequence that isn't a CSI ending in 'm'. Only SGR params that touch bold
/// (0, 1, 22, empty=reset) are interpreted; everything else (color, italic,
/// underline) is preserved verbatim because we just pass the bytes through.
fn update_bold_state(seq: &[u8], external_bold: &mut bool) {
    let n = seq.len();
    if n < 3 || seq[0] != ESC || seq[1] != b'[' || seq[n - 1] != b'm' {
        return;
    }
    let params = &seq[2..n - 1];
    if params.is_empty() {
        *external_bold = false; // \x1b[m == \x1b[0m
        return;
    }
    for part in params.split(|&b| b == b';') {
        match part {
            b"" | b"0" => *external_bold = false,
            b"1" => *external_bold = true,
            b"22" => *external_bold = false,
            _ => {}
        }
    }
}

/// Determine where an ANSI escape sequence starting at `start` (a 0x1b byte) ends.
/// Returns the exclusive end index.
fn find_escape_end(bytes: &[u8], start: usize) -> usize {
    let len = bytes.len();
    if start + 1 >= len {
        return len;
    }
    match bytes[start + 1] {
        b'[' => find_csi_end(bytes, start + 2),
        b']' | b'P' | b'X' | b'^' | b'_' => find_string_end(bytes, start + 2),
        b'(' | b')' | b'*' | b'+' => (start + 3).min(len),
        _ => (start + 2).min(len),
    }
}

/// CSI sequence: parameter/intermediate bytes, then a final byte 0x40..=0x7e.
fn find_csi_end(bytes: &[u8], start: usize) -> usize {
    let len = bytes.len();
    let mut i = start;
    while i < len {
        if matches!(bytes[i], 0x40..=0x7e) {
            return i + 1;
        }
        i += 1;
    }
    len
}

/// OSC / DCS / SOS / PM / APC: terminated by BEL or ST (ESC \).
fn find_string_end(bytes: &[u8], start: usize) -> usize {
    let len = bytes.len();
    let mut i = start;
    while i < len {
        if bytes[i] == BEL {
            return i + 1;
        }
        if bytes[i] == ESC && i + 1 < len && bytes[i + 1] == b'\\' {
            return i + 2;
        }
        i += 1;
    }
    len
}

fn bionic_text<W: Write>(
    text: &str,
    ratio: f32,
    external_bold: bool,
    out: &mut W,
) -> io::Result<()> {
    let mut word_start: Option<usize> = None;
    for (byte_idx, ch) in text.char_indices() {
        if ch.is_whitespace() {
            if let Some(start) = word_start {
                emit_word(&text[start..byte_idx], ratio, external_bold, out)?;
                word_start = None;
            }
            let mut buf = [0u8; 4];
            out.write_all(ch.encode_utf8(&mut buf).as_bytes())?;
        } else if word_start.is_none() {
            word_start = Some(byte_idx);
        }
    }
    if let Some(start) = word_start {
        emit_word(&text[start..], ratio, external_bold, out)?;
    }
    Ok(())
}

fn emit_word<W: Write>(
    word: &str,
    ratio: f32,
    external_bold: bool,
    out: &mut W,
) -> io::Result<()> {
    let char_count = word.chars().count();
    if char_count == 0 {
        return Ok(());
    }
    // If text is already bold from an upstream SGR, skip bionic — adding our own
    // bold-off would cancel the upstream emphasis mid-word.
    if external_bold {
        out.write_all(word.as_bytes())?;
        return Ok(());
    }

    let mut bold_count = ((char_count as f32) * ratio).ceil() as usize;
    if bold_count == 0 {
        bold_count = 1;
    }
    if bold_count > char_count {
        bold_count = char_count;
    }

    let split_byte = word
        .char_indices()
        .nth(bold_count)
        .map(|(b, _)| b)
        .unwrap_or(word.len());

    out.write_all(BOLD_ON)?;
    out.write_all(word[..split_byte].as_bytes())?;
    out.write_all(BOLD_OFF)?;
    out.write_all(word[split_byte..].as_bytes())?;
    Ok(())
}
