"""Planning, conversion and execution of the solar wallpaper, with the command runner faked."""

from __future__ import annotations

import datetime as dt
from pathlib import Path
from typing import TYPE_CHECKING

import pytest

from solar_wallpaper import (
    CommandResult,
    ConversionError,
    DesktopState,
    SetTheme,
    Settings,
    SetWallpaper,
    ToggleNightlight,
    ToolMissingError,
    ensure_converted,
    execute,
    main,
    parse_nightlight_status,
    plan,
    read_desktop_state,
    run_command,
    source_path,
    wallpaper_path,
)
from sun import Location, SolarPhase

if TYPE_CHECKING:
    from collections.abc import Sequence


class FakeRunner:
    """Records every command and answers with one canned result.

    A `magick` call writes an empty file at its output path, the way the real
    converter would, so the rename into place can be exercised.
    """

    __slots__ = ("calls", "result")

    def __init__(self, result: CommandResult | None = None) -> None:
        self.calls: list[tuple[str, ...]] = []
        self.result = result or CommandResult(returncode=0, stdout="")

    def __call__(self, command: Sequence[str], *, timeout: int) -> CommandResult:
        self.calls.append(tuple(command))
        if command[0] == "magick" and self.result.returncode == 0:
            Path(command[-1].removeprefix("jpeg:")).write_bytes(b"")
        return self.result


@pytest.fixture
def settings(tmp_path: Path) -> Settings:
    return Settings.from_env({"SOLAR_CACHE_DIR": str(tmp_path / "cache")}, home=tmp_path)


def state(
    settings: Settings, phase: SolarPhase, *, nightlight_on: bool, theme: str = "tokyo-night"
) -> DesktopState:
    return DesktopState(
        background=wallpaper_path(settings.cache_dir, phase, 9),
        theme=theme,
        nightlight_on=nightlight_on,
    )


def test_defaults_point_at_stockholm_and_the_bluefin_set(tmp_path: Path) -> None:
    settings = Settings.from_env({}, home=tmp_path)
    assert settings.location == Location(latitude=59.3293, longitude=18.0686)
    assert settings.source_dir == Path("/usr/share/backgrounds/bluefin")
    assert settings.cache_dir == (tmp_path / ".local/share/pneuma/solar").resolve()
    assert settings.state_dir == tmp_path / ".local/state/omarchy"
    assert settings.nightlight is True
    assert settings.theme_for(SolarPhase.DAY) == ""


def test_environment_overrides(tmp_path: Path) -> None:
    env = {
        "SOLAR_LATITUDE": "-33.9",
        "SOLAR_LONGITUDE": "151.2",
        "SOLAR_NIGHTLIGHT": "0",
        "SOLAR_DAY_THEME": "catppuccin-latte",
        "SOLAR_NIGHT_THEME": "tokyo-night",
    }
    settings = Settings.from_env(env, home=tmp_path)
    assert settings.location == Location(latitude=-33.9, longitude=151.2)
    assert settings.nightlight is False
    assert settings.theme_for(SolarPhase.DAY) == "catppuccin-latte"
    assert settings.theme_for(SolarPhase.NIGHT) == "tokyo-night"


def test_paths_follow_month_and_phase(tmp_path: Path) -> None:
    assert wallpaper_path(tmp_path, SolarPhase.DAY, 9) == tmp_path / "09-day.jpg"
    assert source_path(tmp_path, SolarPhase.NIGHT, 12) == tmp_path / "12-bluefin-night.jxl"


def test_nothing_to_do_when_the_desktop_already_matches(settings: Settings) -> None:
    assert (
        plan(settings, SolarPhase.DAY, 9, state(settings, SolarPhase.DAY, nightlight_on=False))
        == ()
    )
    assert (
        plan(settings, SolarPhase.NIGHT, 9, state(settings, SolarPhase.NIGHT, nightlight_on=True))
        == ()
    )


def test_sunset_swaps_wallpaper_and_lights_the_night_light(settings: Settings) -> None:
    steps = plan(
        settings, SolarPhase.NIGHT, 9, state(settings, SolarPhase.DAY, nightlight_on=False)
    )
    assert steps == (
        SetWallpaper(
            image=settings.cache_dir / "09-night.jpg",
            source=settings.source_dir / "09-bluefin-night.jxl",
        ),
        ToggleNightlight(),
    )


def test_night_light_is_left_alone_when_disabled(tmp_path: Path) -> None:
    settings = Settings.from_env({"SOLAR_NIGHTLIGHT": "0"}, home=tmp_path)
    steps = plan(settings, SolarPhase.DAY, 9, state(settings, SolarPhase.DAY, nightlight_on=True))
    assert steps == ()


def test_theme_switch_comes_first_and_only_when_it_differs(tmp_path: Path) -> None:
    env = {"SOLAR_DAY_THEME": "catppuccin-latte", "SOLAR_NIGHT_THEME": "tokyo-night"}
    settings = Settings.from_env(env, home=tmp_path)
    steps = plan(
        settings, SolarPhase.DAY, 9, state(settings, SolarPhase.NIGHT, nightlight_on=False)
    )
    assert steps[0] == SetTheme("catppuccin-latte")
    assert steps[1] == SetWallpaper(
        image=settings.cache_dir / "09-day.jpg", source=settings.source_dir / "09-bluefin-day.jxl"
    )
    assert (
        plan(settings, SolarPhase.NIGHT, 9, state(settings, SolarPhase.NIGHT, nightlight_on=True))
        == ()
    )


@pytest.mark.parametrize(
    ("raw", "enabled"),
    [
        ('{"enabled":true,"temperature":4000}', True),
        ('{"enabled":false,"temperature":null}', False),
        ('{"enabled":"yes"}', False),
        ("", False),
        ("not json", False),
    ],
)
def test_nightlight_status_parsing(raw: str, enabled: bool) -> None:
    assert parse_nightlight_status(raw) is enabled


def test_desktop_state_reads_omarchy_state(tmp_path: Path) -> None:
    current = tmp_path / "current"
    current.mkdir()
    image = tmp_path / "wall.jpg"
    image.write_bytes(b"")
    (current / "background").symlink_to(image)
    (current / "theme.name").write_text("tokyo-night\n")
    runner = FakeRunner(CommandResult(returncode=0, stdout='{"enabled":true}'))

    desktop = read_desktop_state(tmp_path, runner)

    assert desktop == DesktopState(
        background=image.resolve(), theme="tokyo-night", nightlight_on=True
    )
    assert runner.calls == [("omarchy-toggle-nightlight", "--status")]


def test_desktop_state_without_omarchy_state(tmp_path: Path) -> None:
    desktop = read_desktop_state(tmp_path, FakeRunner())
    assert desktop == DesktopState(background=None, theme="", nightlight_on=False)


def test_conversion_is_skipped_when_the_target_exists(tmp_path: Path) -> None:
    target = tmp_path / "09-day.jpg"
    target.write_bytes(b"")
    runner = FakeRunner()
    ensure_converted(tmp_path / "missing.jxl", target, runner)
    assert runner.calls == []


def test_conversion_needs_a_source(tmp_path: Path) -> None:
    with pytest.raises(ConversionError, match="no source wallpaper"):
        ensure_converted(tmp_path / "missing.jxl", tmp_path / "out" / "09-day.jpg", FakeRunner())


def test_conversion_runs_magick_into_a_created_directory(tmp_path: Path) -> None:
    source = tmp_path / "09-bluefin-day.jxl"
    source.write_bytes(b"")
    target = tmp_path / "cache" / "09-day.jpg"
    runner = FakeRunner()

    ensure_converted(source, target, runner)

    assert target.exists()
    assert not target.with_suffix(".partial").exists()
    assert runner.calls == [
        (
            "magick",
            str(source),
            "-resize",
            "3840x",
            "-quality",
            "90",
            f"jpeg:{target.with_suffix('.partial')}",
        ),
    ]


def test_conversion_failure_is_reported(tmp_path: Path) -> None:
    source = tmp_path / "09-bluefin-day.jxl"
    source.write_bytes(b"")
    runner = FakeRunner(CommandResult(returncode=1, stdout=""))
    with pytest.raises(ConversionError, match="exited 1"):
        ensure_converted(source, tmp_path / "09-day.jpg", runner)


def test_execute_runs_the_omarchy_commands(tmp_path: Path) -> None:
    image = tmp_path / "09-night.jpg"
    image.write_bytes(b"")
    runner = FakeRunner()

    execute(
        (
            SetTheme("tokyo-night"),
            SetWallpaper(image=image, source=tmp_path / "x.jxl"),
            ToggleNightlight(),
        ),
        runner,
    )

    assert runner.calls == [
        ("omarchy-theme-set", "tokyo-night"),
        ("omarchy-theme-bg-set", str(image)),
        ("omarchy-toggle-nightlight",),
    ]


def test_run_command_rejects_missing_tools() -> None:
    with pytest.raises(ToolMissingError, match="not on PATH"):
        run_command(["pneuma-no-such-tool"], timeout=1)


def test_main_is_a_no_op_while_the_toggle_is_off(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch, capsys: pytest.CaptureFixture[str]
) -> None:
    monkeypatch.setenv("HOME", str(tmp_path))
    runner = FakeRunner()
    assert main(["--dry-run"], run=runner) == 0
    assert runner.calls == []
    assert capsys.readouterr().out == ""


def test_main_dry_run_describes_the_plan(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch, capsys: pytest.CaptureFixture[str]
) -> None:
    monkeypatch.setenv("HOME", str(tmp_path))
    monkeypatch.setenv("SOLAR_CACHE_DIR", str(tmp_path / "cache"))
    runner = FakeRunner(CommandResult(returncode=0, stdout='{"enabled":false}'))
    noon = dt.datetime(2026, 9, 4, 12, 0, tzinfo=dt.UTC).isoformat()

    assert main(["--force", "--dry-run", "--now", noon], run=runner) == 0

    assert capsys.readouterr().out == "day: wallpaper 09-day.jpg\n"
    assert runner.calls == [("omarchy-toggle-nightlight", "--status")]


def test_main_reports_a_failed_step(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch, capsys: pytest.CaptureFixture[str]
) -> None:
    monkeypatch.setenv("HOME", str(tmp_path))
    monkeypatch.setenv("SOLAR_CACHE_DIR", str(tmp_path / "cache"))
    monkeypatch.setenv("SOLAR_SOURCE_DIR", str(tmp_path / "no-sources"))
    midnight = dt.datetime(2026, 9, 4, 0, 0, tzinfo=dt.UTC).isoformat()

    assert main(["--force", "--now", midnight], run=FakeRunner()) == 1

    assert "no source wallpaper" in capsys.readouterr().err
