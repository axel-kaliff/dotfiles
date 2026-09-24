//! The clipboard history on disk: a JSON list, newest first, under
//! ~/.local/state/pneuma/clipboard, with images stored by hash next to it. Writers take a file
//! lock because the text and image watchers capture independently.

use std::fs::{self, File};
use std::io::{self, Read};
use std::os::fd::AsRawFd;
use std::path::PathBuf;
use std::process::Command;

use serde::{Deserialize, Serialize};
use sha2::{Digest, Sha256};

pub const LIMIT: usize = 100;
/// The picker only ever searches and shows a prefix of an entry.
const DISPLAY_CHARS: usize = 8192;

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(tag = "type", rename_all = "lowercase")]
pub enum Entry {
    Text {
        text: String,
    },
    Image {
        mime: String,
        path: PathBuf,
        #[serde(rename = "capturedAt")]
        captured_at: String,
    },
}

impl Entry {
    /// file:// lines, when the text is a copied file list.
    fn file_paths(&self) -> Vec<String> {
        let Entry::Text { text } = self else { return Vec::new() };
        let paths: Vec<String> = text
            .lines()
            .filter_map(|line| {
                let path = line.trim().strip_prefix("file://")?;
                let path = path.strip_prefix("localhost").unwrap_or(path);
                path.starts_with('/').then(|| url_decode(path))
            })
            .collect();
        if paths.len() == text.lines().filter(|l| !l.trim().is_empty()).count() { paths } else { Vec::new() }
    }

    pub fn preview(&self) -> String {
        match self {
            Entry::Image { mime, captured_at, .. } => {
                let kind = if mime == "image/png" { "Screenshot" } else { "Image" };
                format!("{kind} from {captured_at}")
            }
            Entry::Text { text } => {
                let files = self.file_paths();
                match files.len() {
                    0 => text.chars().take(DISPLAY_CHARS).collect::<String>().split_whitespace().collect::<Vec<_>>().join(" "),
                    1 => files[0].rsplit('/').next().unwrap_or(&files[0]).to_owned(),
                    n => format!("{n} files"),
                }
            }
        }
    }

    pub fn matches(&self, needle: &str) -> bool {
        needle.is_empty() || self.preview().to_lowercase().contains(needle)
    }

    /// A single image the row can show: the capture, or the one image file in a copied list.
    pub fn thumbnail(&self) -> Option<PathBuf> {
        match self {
            Entry::Image { path, .. } => Some(path.clone()),
            Entry::Text { .. } => {
                let files = self.file_paths();
                let [file] = files.as_slice() else { return None };
                let lower = file.to_lowercase();
                ["png", "jpg", "jpeg", "webp", "gif", "bmp"].iter().any(|ext| lower.ends_with(&format!(".{ext}"))).then(|| PathBuf::from(file))
            }
        }
    }

    /// Puts the entry back on the clipboard.
    pub fn copy(&self) {
        let child = match self {
            Entry::Text { text } => {
                let mut child = Command::new("wl-copy").stdin(std::process::Stdio::piped()).spawn();
                if let Ok(child) = &mut child {
                    if let Some(mut stdin) = child.stdin.take() {
                        let _ = io::Write::write_all(&mut stdin, text.as_bytes());
                    }
                }
                child
            }
            Entry::Image { mime, path, .. } => {
                let Ok(file) = File::open(path) else { return };
                Command::new("wl-copy").arg("--type").arg(mime).stdin(file).spawn()
            }
        };
        if let Ok(mut child) = child {
            std::thread::spawn(move || child.wait());
        }
    }
}

fn url_decode(path: &str) -> String {
    let bytes = path.as_bytes();
    let mut out = Vec::with_capacity(bytes.len());
    let mut i = 0;
    while i < bytes.len() {
        let decoded = (bytes[i] == b'%' && i + 2 < bytes.len())
            .then(|| u8::from_str_radix(std::str::from_utf8(&bytes[i + 1..i + 3]).ok()?, 16).ok())
            .flatten();
        match decoded {
            Some(byte) => {
                out.push(byte);
                i += 3;
            }
            None => {
                out.push(bytes[i]);
                i += 1;
            }
        }
    }
    String::from_utf8_lossy(&out).into_owned()
}

pub fn dir() -> PathBuf {
    let state = std::env::var_os("XDG_STATE_HOME").map(PathBuf::from).unwrap_or_else(|| {
        PathBuf::from(std::env::var_os("HOME").unwrap_or_default()).join(".local/state")
    });
    state.join("pneuma/clipboard")
}

pub fn load() -> Vec<Entry> {
    fs::read(dir().join("history.json")).ok().and_then(|raw| serde_json::from_slice(&raw).ok()).unwrap_or_default()
}

/// Rewrites the list atomically, so a reader never sees a half-written file.
fn save(entries: &[Entry]) -> io::Result<()> {
    let dir = dir();
    fs::create_dir_all(&dir)?;
    let tmp = dir.join("history.json.tmp");
    fs::write(&tmp, serde_json::to_vec_pretty(entries)?)?;
    fs::rename(tmp, dir.join("history.json"))
}

/// Runs `edit` on the list under the writers' lock and saves the result.
pub fn update(edit: impl FnOnce(&mut Vec<Entry>)) -> io::Result<()> {
    let dir = dir();
    fs::create_dir_all(&dir)?;
    let lock = File::create(dir.join("lock"))?;
    // SAFETY: flock on a file descriptor this process owns; released when `lock` drops.
    if unsafe { libc::flock(lock.as_raw_fd(), libc::LOCK_EX) } != 0 {
        return Err(io::Error::last_os_error());
    }
    let mut entries = load();
    edit(&mut entries);
    entries.truncate(LIMIT);
    save(&entries)
}

fn push_front(entries: &mut Vec<Entry>, entry: Entry) {
    entries.retain(|e| *e != entry);
    entries.insert(0, entry);
}

/// wl-paste --watch mode: the new clipboard content is on stdin. Password managers mark their
/// copies as sensitive; those never enter the history.
pub fn capture(mime: &str) -> io::Result<()> {
    if std::env::var("CLIPBOARD_STATE").is_ok_and(|s| s != "data") {
        return Ok(());
    }
    let types = Command::new("wl-paste").arg("--list-types").output().map(|o| o.stdout).unwrap_or_default();
    if String::from_utf8_lossy(&types).lines().any(|t| t == "x-kde-passwordManagerHint") {
        return Ok(());
    }
    let mut bytes = Vec::new();
    io::stdin().read_to_end(&mut bytes)?;
    let entry = if mime == "text" {
        let text = String::from_utf8_lossy(&bytes).into_owned();
        if text.trim().is_empty() {
            return Ok(());
        }
        Entry::Text { text }
    } else {
        if bytes.is_empty() {
            return Ok(());
        }
        let images = dir().join("images");
        fs::create_dir_all(&images)?;
        let ext = match mime.strip_prefix("image/").unwrap_or("png") {
            "jpeg" => "jpg",
            ext => ext,
        };
        let path = images.join(format!("{:x}.{ext}", Sha256::digest(&bytes)));
        if !path.exists() {
            fs::write(&path, &bytes)?;
        }
        Entry::Image { mime: mime.to_owned(), path, captured_at: jiff::Zoned::now().strftime("%A %H:%M").to_string() }
    };
    update(|entries| push_front(entries, entry))
}
