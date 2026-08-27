// Pure logic for the safeeyes engine: prompt pools and small helpers, kept
// out of Service.qml so the QML side stays a thin state machine.
//
// Prompt texts are carried over from soramanew/safeeyes, the caelestia
// desktop's break app this plugin is ported from.

var SHORT_PROMPTS = [
  "Tightly close your eyes",
  "Roll your eyes a few times to each side",
  "Rotate your eyes in clockwise direction",
  "Rotate your eyes in counter clockwise direction",
  "Blink your eyes",
  "Focus on a point in the far distance",
  "Have some water"
]

var LONG_PROMPTS = [
  "Walk for a while",
  "Lean back at your seat and relax",
  "Do 20 push ups",
  "Do some stretches"
]

function breakTypeFor(count, perLong) {
  return count % perLong === 0 ? "long" : "short"
}

function pickPrompt(kind, rnd) {
  var pool = kind === "long" ? LONG_PROMPTS : SHORT_PROMPTS
  var index = Math.min(pool.length - 1, Math.floor(rnd * pool.length))
  return pool[index]
}

function formatClock(epochMs) {
  var when = new Date(epochMs)
  var hours = when.getHours()
  var minutes = when.getMinutes()
  return (hours < 10 ? "0" : "") + hours + ":" + (minutes < 10 ? "0" : "") + minutes
}
