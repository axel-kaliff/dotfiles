"""Sunrise, sunset and the day/night phase from the sunrise equation.

The NOAA-derived equation Wikipedia documents under "Sunrise equation":
accurate to a few minutes, which is all a wallpaper needs. Latitude is
north-positive, longitude east-positive, results are timezone-aware UTC.
"""

from __future__ import annotations

import datetime as dt
import math
from dataclasses import dataclass
from enum import StrEnum
from typing import Final

J2000: Final = 2451545.0
UNIX_EPOCH_JULIAN_DAY: Final = 2440587.5
SECONDS_PER_DAY: Final = 86400
# Atmospheric refraction plus the solar disc: the sun "rises" when its centre
# is this far below the geometric horizon.
HORIZON_ALTITUDE_DEGREES: Final = -0.833
EARTH_OBLIQUITY_DEGREES: Final = 23.4397


class SolarPhase(StrEnum):
    """Whether the sun is above the horizon."""

    DAY = "day"
    NIGHT = "night"


@dataclass(frozen=True, slots=True)
class Location:
    """A point on Earth in decimal degrees."""

    latitude: float
    longitude: float


@dataclass(frozen=True, slots=True)
class SunTimes:
    """Sunrise and sunset for one date, in UTC."""

    sunrise: dt.datetime
    sunset: dt.datetime


@dataclass(frozen=True, slots=True)
class PolarDay:
    """A date on which the sun never crosses the horizon."""

    phase: SolarPhase


type SolarDay = SunTimes | PolarDay


def _julian_to_datetime(julian_day: float) -> dt.datetime:
    seconds = (julian_day - UNIX_EPOCH_JULIAN_DAY) * SECONDS_PER_DAY
    return dt.datetime.fromtimestamp(seconds, tz=dt.UTC)


def _transit_and_declination(mean_solar_noon: float) -> tuple[float, float]:
    """Julian day of solar noon and the sun's declination in radians."""
    mean_anomaly_degrees = (357.5291 + 0.98560028 * mean_solar_noon) % 360
    anomaly = math.radians(mean_anomaly_degrees)
    equation_of_centre = (
        1.9148 * math.sin(anomaly)
        + 0.0200 * math.sin(2 * anomaly)
        + 0.0003 * math.sin(3 * anomaly)
    )
    ecliptic_longitude = math.radians(
        (mean_anomaly_degrees + equation_of_centre + 180 + 102.9372) % 360
    )
    transit = (
        J2000
        + mean_solar_noon
        + 0.0053 * math.sin(anomaly)
        - 0.0069 * math.sin(2 * ecliptic_longitude)
    )
    declination = math.asin(
        math.sin(ecliptic_longitude) * math.sin(math.radians(EARTH_OBLIQUITY_DEGREES))
    )
    return transit, declination


def solar_day(day: dt.date, location: Location) -> SolarDay:
    """Sunrise and sunset on `day` at `location`, or the polar phase when there are none."""
    days_since_j2000 = (day - dt.date(2000, 1, 1)).days
    transit, declination = _transit_and_declination(days_since_j2000 - location.longitude / 360)
    latitude = math.radians(location.latitude)
    cos_hour_angle = (
        math.sin(math.radians(HORIZON_ALTITUDE_DEGREES))
        - math.sin(latitude) * math.sin(declination)
    ) / (math.cos(latitude) * math.cos(declination))
    if cos_hour_angle >= 1:
        return PolarDay(SolarPhase.NIGHT)
    if cos_hour_angle <= -1:
        return PolarDay(SolarPhase.DAY)
    half_day = math.degrees(math.acos(cos_hour_angle)) / 360
    return SunTimes(
        sunrise=_julian_to_datetime(transit - half_day),
        sunset=_julian_to_datetime(transit + half_day),
    )


def phase_at(moment: dt.datetime, location: Location) -> SolarPhase:
    """The solar phase at a timezone-aware `moment` for `location`.

    The neighbouring dates are checked too, so a moment whose calendar date
    (in its own timezone) differs from the local solar day still lands in
    the right daylight interval.
    """
    match solar_day(moment.date(), location):
        case PolarDay(phase=phase):
            return phase
        case SunTimes():
            pass
    for offset in (-1, 0, 1):
        match solar_day(moment.date() + dt.timedelta(days=offset), location):
            case SunTimes(sunrise=sunrise, sunset=sunset) if sunrise <= moment < sunset:
                return SolarPhase.DAY
    return SolarPhase.NIGHT
