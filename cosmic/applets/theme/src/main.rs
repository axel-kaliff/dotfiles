//! pneuma-theme-apply <colors.toml>: puts an Omarchy palette on COSMIC. The theme builder's
//! accent, background, text and neutral tints and window hint come from the palette; everything
//! else in the builder (gaps, corners, frosting) is kept. The derived theme every COSMIC surface
//! reads is then rebuilt from the builder and written, as cosmic-settings does on a change.

use cosmic::cosmic_config::CosmicConfigEntry;
use cosmic::cosmic_theme::palette::{Srgb, Srgba};
use cosmic::cosmic_theme::{Theme, ThemeBuilder};

/// `#rrggbb` as sRGB components in 0..=1.
fn hex(value: &str) -> Option<[f32; 3]> {
    let digits = value.strip_prefix('#').filter(|d| d.len() == 6)?;
    let n = u32::from_str_radix(digits, 16).ok()?;
    Some([(n >> 16) & 0xff, (n >> 8) & 0xff, n & 0xff].map(|c| c as f32 / 255.0))
}

fn main() -> Result<(), String> {
    let path = std::env::args().nth(1).ok_or("usage: pneuma-theme-apply <colors.toml>")?;
    let raw = std::fs::read_to_string(&path).map_err(|e| format!("{path}: {e}"))?;
    // colors.toml is flat `key = "value"` lines, so no TOML parser is needed.
    let get = |key: &str| {
        raw.lines().find_map(|line| {
            let (k, v) = line.split_once('=')?;
            (k.trim() == key).then(|| v.trim().trim_matches('"').to_owned())
        })
    };
    let color = |key: &str| get(key).as_deref().and_then(hex).ok_or(format!("{path}: no #rrggbb for {key}"));
    let srgb = |[r, g, b]: [f32; 3]| Srgb::new(r, g, b);

    let dark = get("mode").as_deref() != Some("light");
    let builder_config = if dark { ThemeBuilder::dark_config() } else { ThemeBuilder::light_config() }
        .map_err(|e| format!("builder config: {e:?}"))?;
    let mut builder = ThemeBuilder::get_entry(&builder_config).unwrap_or_else(|(_, partial)| partial);

    let [r, g, b] = color("background")?;
    builder.bg_color = Some(Srgba::new(r, g, b, 1.0));
    builder.accent = Some(srgb(color("accent")?));
    builder.neutral_tint = Some(srgb(color("accent")?));
    builder.text_tint = Some(srgb(color("foreground")?));
    builder.window_hint = Some(srgb(color("active_border_color")?));
    builder.write_entry(&builder_config).map_err(|e| format!("write builder: {e:?}"))?;

    let theme_config = if dark { Theme::dark_config() } else { Theme::light_config() }
        .map_err(|e| format!("theme config: {e:?}"))?;
    builder.build().write_entry(&theme_config).map_err(|e| format!("write theme: {e:?}"))?;
    Ok(())
}
