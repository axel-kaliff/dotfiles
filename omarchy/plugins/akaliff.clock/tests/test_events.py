import sqlite3
import time
from collections.abc import Iterator
from contextlib import closing
from datetime import UTC, date, datetime
from pathlib import Path
from zoneinfo import ZoneInfo

import pytest

from events import occurrences

SCHEMA = """CREATE TABLE cal_events (
    cal_id TEXT,
    id TEXT,
    time_created INTEGER,
    last_modified INTEGER,
    title TEXT,
    priority INTEGER,
    privacy TEXT,
    ical_status TEXT,
    flags INTEGER,
    event_start INTEGER,
    event_end INTEGER,
    event_stamp INTEGER,
    event_start_tz TEXT,
    event_end_tz TEXT,
    recurrence_id INTEGER,
    recurrence_id_tz TEXT,
    alarm_last_ack INTEGER,
    offline_journal INTEGER);
CREATE TABLE cal_recurrence (
    item_id TEXT,
    cal_id TEXT,
    icalString TEXT);
"""


@pytest.fixture
def profile(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> Iterator[Path]:
    with monkeypatch.context() as environment:
        environment.setenv("TZ", "Europe/Stockholm")
        time.tzset()
        (tmp_path / "prefs.js").write_text("")
        (tmp_path / "calendar-data").mkdir()
        for name in ("local.sqlite", "cache.sqlite"):
            with closing(
                sqlite3.connect(tmp_path / "calendar-data" / name, timeout=5)
            ) as connection:
                connection.executescript(SCHEMA)
        yield tmp_path
    time.tzset()


def prtime(value: str, zone: str) -> int:
    tz = UTC if zone == "floating" else ZoneInfo(zone)
    return int(datetime.fromisoformat(value).replace(tzinfo=tz).timestamp() * 1_000_000)


def add_event(
    profile: Path,
    uid: str,
    start: str,
    end: str,
    *,
    zone: str = "Europe/Berlin",
    calendar: str = "enabled",
    title: str = "Meeting",
    flags: int = 0,
    recurrence_id: str | None = None,
    status: str | None = None,
    offline: int | None = None,
    database: str = "cache.sqlite",
) -> None:
    with closing(
        sqlite3.connect(profile / "calendar-data" / database, timeout=5)
    ) as connection:
        connection.execute(
            """INSERT INTO cal_events
            (cal_id, id, title, flags, event_start, event_end, event_start_tz,
             event_end_tz, recurrence_id, recurrence_id_tz, ical_status, offline_journal)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)""",
            (
                calendar,
                uid,
                title,
                flags,
                prtime(start, zone),
                prtime(end, zone),
                zone,
                zone,
                prtime(recurrence_id, zone) if recurrence_id is not None else None,
                zone if recurrence_id is not None else None,
                status,
                offline,
            ),
        )
        connection.commit()


def add_recurrence(
    profile: Path, uid: str, line: str, calendar: str = "enabled"
) -> None:
    with closing(
        sqlite3.connect(profile / "calendar-data/cache.sqlite", timeout=5)
    ) as connection:
        connection.execute(
            "INSERT INTO cal_recurrence VALUES (?, ?, ?)", (uid, calendar, line)
        )
        connection.commit()


def weekly(profile: Path) -> None:
    add_event(profile, "weekly", "2026-10-18T09:00", "2026-10-18T10:00", flags=16)
    add_recurrence(profile, "weekly", "RRULE:FREQ=WEEKLY;\r\n COUNT=4\r\n")


def test_weekly_keeps_wall_time_across_dst(profile: Path) -> None:
    weekly(profile)
    assert occurrences(profile, date(2026, 10, 18), date(2026, 11, 9)) == [
        {"date": "2026-10-18", "time": "09:00", "title": "Meeting"},
        {"date": "2026-10-25", "time": "09:00", "title": "Meeting"},
        {"date": "2026-11-01", "time": "09:00", "title": "Meeting"},
        {"date": "2026-11-08", "time": "09:00", "title": "Meeting"},
    ]


def test_excluded_moved_and_cancelled_occurrences(profile: Path) -> None:
    weekly(profile)
    add_recurrence(profile, "weekly", "EXDATE;TZID=Europe/Berlin:20261025T090000\r\n")
    add_event(
        profile,
        "weekly",
        "2026-11-02T13:00",
        "2026-11-02T14:00",
        recurrence_id="2026-11-01T09:00",
        title="Moved",
    )
    add_event(
        profile,
        "weekly",
        "2026-11-08T09:00",
        "2026-11-08T10:00",
        recurrence_id="2026-11-08T09:00",
        status="CANCELLED",
    )
    assert occurrences(profile, date(2026, 10, 18), date(2026, 11, 9)) == [
        {"date": "2026-10-18", "time": "09:00", "title": "Meeting"},
        {"date": "2026-11-02", "time": "13:00", "title": "Moved"},
    ]


def test_floating_all_day_spans_dates(profile: Path) -> None:
    add_event(
        profile,
        "holiday",
        "2026-10-07",
        "2026-10-09",
        zone="floating",
        flags=8,
        title="Holiday",
        database="local.sqlite",
    )
    assert occurrences(profile, date(2026, 10, 7), date(2026, 10, 10)) == [
        {"date": "2026-10-07", "time": "", "title": "Holiday"},
        {"date": "2026-10-08", "time": "", "title": "Holiday"},
    ]
    assert occurrences(profile, date(2026, 10, 8), date(2026, 10, 9)) == [
        {"date": "2026-10-08", "time": "", "title": "Holiday"},
    ]


@pytest.mark.parametrize("offline", [None, 1, 2, 4])
def test_pending_delete(profile: Path, offline: int | None) -> None:
    add_event(
        profile, "deleted", "2026-10-07T09:00", "2026-10-07T10:00", offline=offline
    )
    expected = (
        []
        if offline == 4
        else [{"date": "2026-10-07", "time": "09:00", "title": "Meeting"}]
    )
    assert occurrences(profile, date(2026, 10, 7), date(2026, 10, 8)) == expected


def test_disabled_calendar(profile: Path) -> None:
    (profile / "prefs.js").write_text(
        'user_pref("calendar.registry.hidden.disabled", true);\n'
        'user_pref("calendar.registry.enabled.disabled", false);\n'
    )
    add_event(
        profile, "shared", "2026-10-07T09:00", "2026-10-07T10:00", calendar="hidden"
    )
    add_event(profile, "shared", "2026-10-07T11:00", "2026-10-07T12:00")
    assert occurrences(profile, date(2026, 10, 7), date(2026, 10, 8)) == [
        {"date": "2026-10-07", "time": "11:00", "title": "Meeting"},
    ]


def test_timed_event_outside_window(profile: Path) -> None:
    add_event(profile, "before", "2026-10-06T23:00", "2026-10-07T01:00")
    add_event(profile, "after", "2026-10-08T00:00", "2026-10-08T01:00")
    assert occurrences(profile, date(2026, 10, 7), date(2026, 10, 8)) == []


def test_sorting_floating_and_calendar_uid_isolation(profile: Path) -> None:
    add_event(profile, "same", "2026-10-07T12:00", "2026-10-07T13:00", title="Zulu")
    add_event(
        profile,
        "same",
        "2026-10-07T12:00",
        "2026-10-07T13:00",
        calendar="second",
        title="Alpha",
        database="local.sqlite",
    )
    add_event(
        profile, "floating", "2026-10-07T09:00", "2026-10-07T10:00", zone="floating"
    )
    add_event(profile, "all-day", "2026-10-07", "2026-10-08", zone="UTC", flags=8)
    add_event(
        profile, "cancelled", "2026-10-07T08:00", "2026-10-07T09:00", status="CANCELLED"
    )
    assert occurrences(profile, date(2026, 10, 7), date(2026, 10, 8)) == [
        {"date": "2026-10-07", "time": "", "title": "Meeting"},
        {"date": "2026-10-07", "time": "09:00", "title": "Meeting"},
        {"date": "2026-10-07", "time": "12:00", "title": "Alpha"},
        {"date": "2026-10-07", "time": "12:00", "title": "Zulu"},
    ]
