// Run with: node omarchy/plugins/akaliff.clock/tests/agenda-days.test.mjs
import assert from "node:assert/strict"
import { createRequire } from "node:module"
import { test } from "node:test"

const require = createRequire(import.meta.url)
const Model = require("../Model.js")

process.env.TZ = "Europe/Stockholm"

test("agenda days are chronological and preserve input order within each day", () => {
  const events = [
    { date: "2026-10-14", time: "14:00", title: "Last day afternoon" },
    { date: "2026-10-08", time: "13:00", title: "Tomorrow afternoon" },
    { date: "2026-10-07", time: "12:00", title: "Today noon" },
    { date: "2026-10-14", time: "09:00", title: "Last day morning" },
    { date: "2026-10-07", time: "", title: "Today all day" },
    { date: "2026-10-08", time: "08:00", title: "Tomorrow morning" },
  ]

  assert.deepEqual(Model.agendaDays(events, new Date(2026, 9, 7)), [
    { date: new Date(2026, 9, 7), offset: 0, events: [events[2], events[4]] },
    { date: new Date(2026, 9, 8), offset: 1, events: [events[1], events[5]] },
    { date: new Date(2026, 9, 14), offset: 7, events: [events[0], events[3]] },
  ])
})

test("yesterday and today plus eight days are outside the agenda", () => {
  const events = [
    { date: "2026-10-06", time: "23:00", title: "Yesterday" },
    { date: "2026-10-15", time: "00:00", title: "Outside" },
  ]

  assert.deepEqual(Model.agendaDays(events, new Date(2026, 9, 7)), [])
})

test("no events produce no agenda days", () => {
  assert.deepEqual(Model.agendaDays([], new Date(2026, 9, 7)), [])
})

test("agenda dates stay consecutive across Stockholm's autumn DST change", () => {
  const keys = [
    "2026-10-24",
    "2026-10-25",
    "2026-10-26",
    "2026-10-27",
    "2026-10-28",
    "2026-10-29",
    "2026-10-30",
    "2026-10-31",
  ]
  const events = keys.map(date => ({ date, time: "09:00", title: "Daily" }))
  const days = Model.agendaDays(events, new Date(2026, 9, 24))

  assert.deepEqual(days.map(day => Model.keyForDate(day.date)), keys)
})
