"""The sunrise equation against almanac times, the polar edge cases, and its invariants."""

from __future__ import annotations

import datetime as dt

import pytest
from hypothesis import given
from hypothesis import strategies as st

from sun import Location, PolarDay, SolarPhase, SunTimes, phase_at, solar_day

STOCKHOLM = Location(latitude=59.3293, longitude=18.0686)
LONGYEARBYEN = Location(latitude=78.2232, longitude=15.6267)
NULL_ISLAND = Location(latitude=0.0, longitude=0.0)
ALMANAC_TOLERANCE = dt.timedelta(minutes=8)


def utc(year: int, month: int, day: int, hour: int, minute: int) -> dt.datetime:
    return dt.datetime(year, month, day, hour, minute, tzinfo=dt.UTC)


@pytest.mark.parametrize(
    ("location", "day", "sunrise", "sunset"),
    [
        # Stockholm, 03:31 and 22:08 CEST.
        (STOCKHOLM, dt.date(2026, 6, 21), utc(2026, 6, 21, 1, 31), utc(2026, 6, 21, 20, 8)),
        # Stockholm, 08:43 and 14:48 CET.
        (STOCKHOLM, dt.date(2026, 12, 21), utc(2026, 12, 21, 7, 43), utc(2026, 12, 21, 13, 48)),
        # Equinox on the equator: a twelve-hour day around 06:00 UTC.
        (NULL_ISLAND, dt.date(2026, 3, 20), utc(2026, 3, 20, 5, 57), utc(2026, 3, 20, 18, 4)),
    ],
)
def test_matches_the_almanac(
    location: Location, day: dt.date, sunrise: dt.datetime, sunset: dt.datetime
) -> None:
    match solar_day(day, location):
        case SunTimes(sunrise=computed_rise, sunset=computed_set):
            assert abs(computed_rise - sunrise) <= ALMANAC_TOLERANCE
            assert abs(computed_set - sunset) <= ALMANAC_TOLERANCE
        case PolarDay():
            pytest.fail("expected a sunrise")


@pytest.mark.parametrize(
    ("day", "phase"),
    [
        (dt.date(2026, 12, 21), SolarPhase.NIGHT),
        (dt.date(2026, 6, 21), SolarPhase.DAY),
    ],
)
def test_polar_days_have_no_horizon_crossing(day: dt.date, phase: SolarPhase) -> None:
    assert solar_day(day, LONGYEARBYEN) == PolarDay(phase)
    assert phase_at(dt.datetime.combine(day, dt.time(12), tzinfo=dt.UTC), LONGYEARBYEN) is phase


@pytest.mark.parametrize(
    ("moment", "phase"),
    [
        (utc(2026, 6, 21, 12, 0), SolarPhase.DAY),
        (utc(2026, 6, 21, 23, 30), SolarPhase.NIGHT),
        # Half past midnight local time, expressed in the local zone.
        (
            dt.datetime(2026, 6, 22, 0, 30, tzinfo=dt.timezone(dt.timedelta(hours=2))),
            SolarPhase.NIGHT,
        ),
        # Late evening before a midsummer sunset.
        (
            dt.datetime(2026, 6, 21, 21, 30, tzinfo=dt.timezone(dt.timedelta(hours=2))),
            SolarPhase.DAY,
        ),
    ],
)
def test_phase_in_stockholm(moment: dt.datetime, phase: SolarPhase) -> None:
    assert phase_at(moment, STOCKHOLM) is phase


temperate_locations = st.builds(
    Location,
    latitude=st.floats(min_value=-64, max_value=64),
    longitude=st.floats(min_value=-180, max_value=180),
)
dates = st.dates(min_value=dt.date(2000, 1, 1), max_value=dt.date(2100, 12, 31))
ONE_MINUTE = dt.timedelta(minutes=1)
ONE_DAY = dt.timedelta(days=1)


@given(location=temperate_locations, day=dates)
def test_temperate_days_have_a_sunrise_before_a_sunset(location: Location, day: dt.date) -> None:
    match solar_day(day, location):
        case SunTimes(sunrise=sunrise, sunset=sunset):
            assert dt.timedelta(0) < sunset - sunrise < ONE_DAY
            noon = dt.datetime.combine(day, dt.time(12), tzinfo=dt.UTC)
            assert abs(sunrise - noon) < ONE_DAY
        case PolarDay():
            pytest.fail("no polar days below 64 degrees")


@given(location=temperate_locations, day=dates)
def test_phase_flips_exactly_at_the_horizon(location: Location, day: dt.date) -> None:
    match solar_day(day, location):
        case SunTimes(sunrise=sunrise, sunset=sunset):
            assert phase_at(sunrise - ONE_MINUTE, location) is SolarPhase.NIGHT
            assert phase_at(sunrise, location) is SolarPhase.DAY
            assert phase_at(sunset - ONE_MINUTE, location) is SolarPhase.DAY
            assert phase_at(sunset, location) is SolarPhase.NIGHT
        case PolarDay():
            pytest.fail("no polar days below 64 degrees")
