use std::env;
use std::io::{self, Read, Write};
use std::process::ExitCode;

use bionify::transform;

const DEFAULT_RATIO: f32 = 0.4;

const HELP: &str = "\
bionify — ANSI-aware bionic reading filter

Reads stdin (or a positional text argument), applies bionic bold to the
leading portion of each word, and passes ANSI escape sequences through
verbatim. Composes with renderers like mdcat, glow, bat, git diff.

USAGE:
    bionify [OPTIONS] [TEXT...]

OPTIONS:
    -r, --ratio <FLOAT>   Proportion of each word to bold (0.0–1.0, default 0.4)
        --no-color        Pass input through unchanged (also: NO_COLOR=1)
    -h, --help            Show this help
    -V, --version         Show version

EXAMPLES:
    cat README.md | bionify
    mdcat README.md | bionify | less -R
    git diff | bionify
    bionify \"some text\"
";

fn main() -> ExitCode {
    match run() {
        Ok(()) => ExitCode::SUCCESS,
        Err(msg) => {
            eprintln!("bionify: {msg}");
            ExitCode::FAILURE
        }
    }
}

fn run() -> Result<(), String> {
    let mut ratio = DEFAULT_RATIO;
    let mut no_color = env::var_os("NO_COLOR").is_some();
    let mut positional: Vec<String> = Vec::new();

    let mut args = env::args().skip(1);
    while let Some(arg) = args.next() {
        match arg.as_str() {
            "-h" | "--help" => {
                print!("{HELP}");
                return Ok(());
            }
            "-V" | "--version" => {
                println!("bionify {}", env!("CARGO_PKG_VERSION"));
                return Ok(());
            }
            "--no-color" => no_color = true,
            "-r" | "--ratio" => {
                let val = args
                    .next()
                    .ok_or_else(|| "--ratio requires a value".to_string())?;
                let r: f32 = val
                    .parse()
                    .map_err(|_| format!("invalid ratio: {val}"))?;
                if !(r > 0.0 && r <= 1.0) {
                    return Err(format!("ratio must be in (0.0, 1.0], got {r}"));
                }
                ratio = r;
            }
            other if other.starts_with('-') && other != "-" => {
                return Err(format!("unknown option: {other}"));
            }
            _ => positional.push(arg),
        }
    }

    let input: String = if positional.is_empty() {
        let mut s = String::new();
        io::stdin()
            .read_to_string(&mut s)
            .map_err(|e| format!("read stdin: {e}"))?;
        s
    } else {
        positional.join(" ")
    };

    let stdout = io::stdout();
    let mut out = stdout.lock();

    let write_result = if no_color {
        out.write_all(input.as_bytes())
    } else {
        transform(&input, ratio, &mut out)
    };

    match write_result {
        Ok(()) => {}
        Err(e) if e.kind() == io::ErrorKind::BrokenPipe => return Ok(()),
        Err(e) => return Err(format!("write: {e}")),
    }
    out.flush().ok();
    Ok(())
}
