"""Drive the wallpaper, night light and theme from the sun's position.

A macOS-style dynamic desktop on Omarchy. The Bluefin image ships a day and a
night wallpaper for every month of the year; this picks the pair for the
current month, shows the day or night half according to sunrise and sunset,
and converts the JPEG XL source once into a JPEG the shell can render. The
night light follows the same clock, and a day and a night theme can be named
too (SOLAR_DAY_THEME / SOLAR_NIGHT_THEME). Runs from a systemd user timer and
from the theme-set hook, and only acts while the `solar-wallpaper` Omarchy
toggle is on: `omarchy toggle solar-wallpaper on`.
"""

from __future__ import annotations

import argparse
import datetime as dt
import json
import os
import shutil
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import TYPE_CHECKING, Final, Protocol

from sun import Location, SolarPhase, phase_at

if TYPE_CHECKING:
    from collections.abc import Mapping, Sequence

TOGGLE_NAME: Final = "solar-wallpaper"
TARGET_WIDTH: Final = 3840
JPEG_QUALITY: Final = 90
CONVERT_TIMEOUT_SECONDS: Final = 180
COMMAND_TIMEOUT_SECONDS: Final = 60


class SolarWallpaperError(Exception):
    """A step the desktop could not carry out."""


class ToolMissingError(SolarWallpaperError):
    """A command this script relies on is not on PATH."""


class ConversionError(SolarWallpaperError):
    """ImageMagick could not produce a wallpaper from its source."""


@dataclass(frozen=True, slots=True)
class Settings:
    """Everything configurable, read from SOLAR_* environment variables."""

    location: Location
    source_dir: Path
    cache_dir: Path
    state_dir: Path
    nightlight: bool
    day_theme: str
    night_theme: str

    @classmethod
    def from_env(cls, env: Mapping[str, str], home: Path) -> Settings:
        """Defaults: Stockholm, the Bluefin set, night light on, no theme switching."""
        return cls(
            location=Location(
                latitude=float(env.get("SOLAR_LATITUDE", "59.3293")),
                longitude=float(env.get("SOLAR_LONGITUDE", "18.0686")),
            ),
            source_dir=Path(env.get("SOLAR_SOURCE_DIR", "/usr/share/backgrounds/bluefin")),
            cache_dir=Path(
                env.get("SOLAR_CACHE_DIR", str(home / ".local/share/pneuma/solar"))
            ).resolve(),
            state_dir=home / ".local/state/omarchy",
            nightlight=env.get("SOLAR_NIGHTLIGHT", "1") == "1",
            day_theme=env.get("SOLAR_DAY_THEME", ""),
            night_theme=env.get("SOLAR_NIGHT_THEME", ""),
        )

    def theme_for(self, phase: SolarPhase) -> str:
        """The theme named for `phase`, or "" when themes are left alone."""
        return self.day_theme if phase is SolarPhase.DAY else self.night_theme


@dataclass(frozen=True, slots=True)
class DesktopState:
    """What the desktop shows right now."""

    background: Path | None
    theme: str
    nightlight_on: bool


@dataclass(frozen=True, slots=True)
class SetTheme:
    """Apply an Omarchy theme by slug."""

    name: str


@dataclass(frozen=True, slots=True)
class SetWallpaper:
    """Show `image`, converting it from `source` first if it does not exist yet."""

    image: Path
    source: Path


@dataclass(frozen=True, slots=True)
class ToggleNightlight:
    """Flip the night light."""


type Step = SetTheme | SetWallpaper | ToggleNightlight


@dataclass(frozen=True, slots=True)
class CommandResult:
    """Exit status and captured stdout of one command."""

    returncode: int
    stdout: str


class Runner(Protocol):
    """Runs a command. The seam the tests replace."""

    def __call__(self, command: Sequence[str], *, timeout: int) -> CommandResult: ...


def run_command(command: Sequence[str], *, timeout: int) -> CommandResult:
    """Run `command` with its executable resolved on PATH, capturing stdout."""
    executable = shutil.which(command[0])
    if executable is None:
        raise ToolMissingError(f"{command[0]} is not on PATH")
    completed = subprocess.run(
        [executable, *command[1:]],
        check=False,
        timeout=timeout,
        capture_output=True,
        text=True,
    )
    return CommandResult(returncode=completed.returncode, stdout=completed.stdout)


def wallpaper_path(cache_dir: Path, phase: SolarPhase, month: int) -> Path:
    """Where the converted wallpaper for `phase` in `month` lives."""
    return cache_dir / f"{month:02d}-{phase}.jpg"


def source_path(source_dir: Path, phase: SolarPhase, month: int) -> Path:
    """The Bluefin JPEG XL the converted wallpaper is made from."""
    return source_dir / f"{month:02d}-bluefin-{phase}.jxl"


def toggle_enabled(state_dir: Path) -> bool:
    """Whether `omarchy toggle solar-wallpaper on` has been run."""
    return (state_dir / "toggles" / TOGGLE_NAME).exists()


def parse_nightlight_status(raw: str) -> bool:
    """Read the `enabled` flag out of omarchy-toggle-nightlight --status output."""
    try:
        status = json.loads(raw or "{}")
    except json.JSONDecodeError:
        return False
    return status.get("enabled") is True


def read_desktop_state(state_dir: Path, run: Runner) -> DesktopState:
    """Current background, theme slug and night light state."""
    background_link = state_dir / "current" / "background"
    background = background_link.resolve() if background_link.is_symlink() else None
    theme_file = state_dir / "current" / "theme.name"
    theme = theme_file.read_text().strip() if theme_file.exists() else ""
    status = run(["omarchy-toggle-nightlight", "--status"], timeout=COMMAND_TIMEOUT_SECONDS)
    return DesktopState(
        background=background,
        theme=theme,
        nightlight_on=parse_nightlight_status(status.stdout),
    )


def plan(
    settings: Settings, phase: SolarPhase, month: int, state: DesktopState
) -> tuple[Step, ...]:
    """The steps that take the desktop from `state` to what `phase` calls for."""
    steps: list[Step] = []
    theme = settings.theme_for(phase)
    if theme and theme != state.theme:
        steps.append(SetTheme(theme))
    image = wallpaper_path(settings.cache_dir, phase, month)
    if state.background != image:
        steps.append(
            SetWallpaper(image=image, source=source_path(settings.source_dir, phase, month))
        )
    if settings.nightlight and state.nightlight_on != (phase is SolarPhase.NIGHT):
        steps.append(ToggleNightlight())
    return tuple(steps)


def ensure_converted(source: Path, target: Path, run: Runner) -> None:
    """Convert `source` into `target` unless it is already there.

    The JPEG is written next to the target and renamed into place, so a
    second run (the timer and the theme-set hook can coincide) never sees a
    half-written file as done.
    """
    if target.exists():
        return
    if not source.exists():
        raise ConversionError(f"no source wallpaper at {source}")
    target.parent.mkdir(parents=True, exist_ok=True)
    partial = target.with_suffix(".partial")
    result = run(
        [
            "magick",
            str(source),
            "-resize",
            f"{TARGET_WIDTH}x",
            "-quality",
            str(JPEG_QUALITY),
            f"jpeg:{partial}",
        ],
        timeout=CONVERT_TIMEOUT_SECONDS,
    )
    if result.returncode != 0 or not partial.exists():
        raise ConversionError(f"magick exited {result.returncode} converting {source}")
    partial.replace(target)


def execute(steps: Sequence[Step], run: Runner) -> None:
    """Carry out `steps` in order."""
    for step in steps:
        match step:
            case SetTheme(name=name):
                run(["omarchy-theme-set", name], timeout=COMMAND_TIMEOUT_SECONDS)
            case SetWallpaper(image=image, source=source):
                ensure_converted(source, image, run)
                run(["omarchy-theme-bg-set", str(image)], timeout=COMMAND_TIMEOUT_SECONDS)
            case ToggleNightlight():
                run(["omarchy-toggle-nightlight"], timeout=COMMAND_TIMEOUT_SECONDS)


def describe(step: Step) -> str:
    """One line per step, for --dry-run."""
    match step:
        case SetTheme(name=name):
            return f"theme {name}"
        case SetWallpaper(image=image):
            return f"wallpaper {image.name}"
        case ToggleNightlight():
            return "toggle night light"


@dataclass(frozen=True, slots=True)
class Options:
    """Command line options."""

    now: dt.datetime | None
    dry_run: bool
    force: bool


def parse_args(argv: Sequence[str] | None) -> Options:
    """Parse the command line; `now` stays None when the real clock should be used."""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--now", type=dt.datetime.fromisoformat, help="pretend it is this ISO 8601 time"
    )
    parser.add_argument(
        "--dry-run", action="store_true", help="print the steps instead of running them"
    )
    parser.add_argument(
        "--force", action="store_true", help=f"act even when the {TOGGLE_NAME} toggle is off"
    )
    namespace = parser.parse_args(argv)
    return Options(now=namespace.now, dry_run=namespace.dry_run, force=namespace.force)


def main(argv: Sequence[str] | None = None, run: Runner = run_command) -> int:
    """Entry point: 0 when the desktop matches the sun, 1 when a step failed."""
    options = parse_args(argv)
    settings = Settings.from_env(os.environ, Path.home())
    if not (options.force or toggle_enabled(settings.state_dir)):
        return 0
    now = (options.now or dt.datetime.now(tz=dt.UTC)).astimezone()
    phase = phase_at(now, settings.location)
    try:
        steps = plan(settings, phase, now.month, read_desktop_state(settings.state_dir, run))
        if options.dry_run:
            print(f"{phase}: {', '.join(describe(step) for step in steps) or 'nothing to do'}")
        else:
            execute(steps, run)
    except SolarWallpaperError as error:
        print(f"solar-wallpaper: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
