#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.12"
# dependencies = ["icalendar", "recurring-ical-events"]
# ///

import configparser
import json
import re
import sqlite3
import sys
from contextlib import closing
from datetime import UTC, date, datetime, timedelta
from pathlib import Path
from typing import TypedDict
from zoneinfo import ZoneInfo

import recurring_ical_events
from icalendar import Calendar, Component, Event


class Occurrence(TypedDict):
    date: str
    time: str
    title: str
    calendar: str
    id: str
    rid: str


def stored_date(value: int, zone: str, all_day: bool) -> date | datetime:
    instant = datetime.fromtimestamp(value / 1_000_000, tz=UTC)
    if zone == "floating":
        instant = instant.replace(tzinfo=None)
    else:
        instant = instant.astimezone(ZoneInfo(zone))
    return instant.date() if all_day else instant


def event_from_row(row: sqlite3.Row, connection: sqlite3.Connection) -> Component:
    lines = []
    if row["flags"] & 16 and row["recurrence_id"] is None:
        for recurrence in connection.execute(
            "SELECT icalString FROM cal_recurrence WHERE item_id = ? AND cal_id = ?",
            (row["id"], row["cal_id"]),
        ):
            lines.append(recurrence[0].replace("\r\n ", "").rstrip("\r\n"))
    event = Event.from_ical("\r\n".join(["BEGIN:VEVENT", *lines, "END:VEVENT"]))
    event.add("uid", row["id"])
    event.add("summary", row["title"])
    if row["ical_status"] is not None:
        event.add("status", row["ical_status"])
    all_day = bool(row["flags"] & 8)
    event.add(
        "dtstart", stored_date(row["event_start"], row["event_start_tz"], all_day)
    )
    event.add("dtend", stored_date(row["event_end"], row["event_end_tz"], all_day))
    if row["recurrence_id"] is not None:
        event.add(
            "recurrence-id",
            stored_date(
                row["recurrence_id"],
                row["recurrence_id_tz"],
                bool(row["flags"] & 512),
            ),
        )
    return event


def recurrence_id(value: date | datetime) -> str:
    match value:
        case datetime() as instant:
            if instant.tzinfo is not None:
                return instant.astimezone(UTC).strftime("%Y%m%dT%H%M%SZ")
            return instant.strftime("%Y%m%dT%H%M%S")
        case date() as day:
            return day.strftime("%Y%m%d")
    raise TypeError("RECURRENCE-ID must be a date or datetime")


def event_occurrences(
    event: Component, cal_id: str, start: date, end: date
) -> list[Occurrence]:
    if event.get("status") == "CANCELLED":
        return []
    title = str(event["summary"])
    item_id = str(event["uid"])
    rid = recurrence_id(event.decoded("recurrence-id"))
    match event.decoded("dtstart"):
        case datetime() as instant:
            local = instant.astimezone() if instant.tzinfo is not None else instant
            day = local.date()
            if start <= day < end:
                return [
                    {
                        "date": day.isoformat(),
                        "time": local.strftime("%H:%M"),
                        "title": title,
                        "calendar": cal_id,
                        "id": item_id,
                        "rid": rid,
                    }
                ]
            return []
        case date() as first:
            last: date = event.decoded("dtend")
            day = max(first, start)
            result: list[Occurrence] = []
            while day < min(last, end):
                result.append(
                    {
                        "date": day.isoformat(),
                        "time": "",
                        "title": title,
                        "calendar": cal_id,
                        "id": item_id,
                        "rid": rid,
                    }
                )
                day += timedelta(days=1)
            return result
    raise TypeError("DTSTART must be a date or datetime")


def occurrences(profile_dir: Path, start: date, end: date) -> list[Occurrence]:
    disabled = set()
    pattern = re.compile(r'user_pref\("calendar\.registry\.(.+)\.disabled",\s*true\);')
    with (profile_dir / "prefs.js").open() as prefs:
        for line in prefs:
            match = pattern.search(line)
            if match:
                disabled.add(match[1])

    calendars: dict[str, Calendar] = {}
    for name in ("local.sqlite", "cache.sqlite"):
        path = profile_dir / "calendar-data" / name
        with closing(
            sqlite3.connect(f"file:{path}?mode=ro", uri=True, timeout=5)
        ) as connection:
            connection.row_factory = sqlite3.Row
            for row in connection.execute(
                "SELECT * FROM cal_events WHERE offline_journal IS NULL OR offline_journal != 4"
            ):
                if row["cal_id"] not in disabled:
                    calendar = calendars.setdefault(row["cal_id"], Calendar())
                    calendar.add_component(event_from_row(row, connection))

    result: list[Occurrence] = []
    for cal_id, calendar in calendars.items():
        for event in recurring_ical_events.of(calendar).between(start, end):
            result.extend(event_occurrences(event, cal_id, start, end))
    return sorted(result, key=lambda item: (item["date"], item["time"], item["title"]))


def main() -> None:
    base = Path.home() / ".var/app/org.mozilla.thunderbird_esr/.thunderbird"
    profiles = configparser.ConfigParser()
    with (base / "profiles.ini").open() as source:
        profiles.read_file(source)
    section = next(name for name in profiles.sections() if name.startswith("Install"))
    profile = base / profiles[section]["Default"]
    print(
        json.dumps(
            occurrences(
                profile,
                date.fromisoformat(sys.argv[1]),
                date.fromisoformat(sys.argv[2]),
            )
        )
    )


if __name__ == "__main__":
    main()
