// Run with: node omarchy/plugins/pneuma.overview/tests/overview-model.test.mjs
//
// OverviewModel.js is a QML library, so it opens with a `.pragma library`
// line that is not valid JavaScript. Dropping that one line is the whole of
// the adaptation; everything below exercises the shipped source.
import assert from "node:assert/strict"
import { readFileSync } from "node:fs"
import { test } from "node:test"
import { dirname, join } from "node:path"
import { fileURLToPath } from "node:url"

const source = readFileSync(join(dirname(fileURLToPath(import.meta.url)), "..", "OverviewModel.js"), "utf8")
const Model = new Function(`${source.split("\n").slice(1).join("\n")}
  return { gridShape, windowRect, exposeRects, clamp01, lerp, lerpRect }`)()

const MONITOR = { x: 0, y: 0, width: 1920, height: 1200, scale: 1.0 }
const PANEL = { width: 1920, height: 1200 }
const ASPECT = PANEL.width / PANEL.height
const EPSILON = 0.01

// The area the windows spread into: the screen, inset the way the panel insets it.
const ROOM = { x: 56, y: 56, width: PANEL.width - 112, height: PANEL.height - 112 }
const SCREEN = { x: 0, y: 0, width: PANEL.width, height: PANEL.height }

test("the grid stays as square as the count allows", () => {
  assert.deepEqual([1, 2, 3, 4, 5, 6, 7].map((n) => Model.gridShape(n)), [
    { cols: 1, rows: 1 }, { cols: 2, rows: 1 }, { cols: 2, rows: 2 }, { cols: 2, rows: 2 },
    { cols: 3, rows: 2 }, { cols: 3, rows: 2 }, { cols: 3, rows: 3 },
  ])
  assert.deepEqual(Model.gridShape(0), { cols: 1, rows: 1 })
})

test("a full-screen window covers the whole screen, whatever the monitor scale", () => {
  for (const monitor of [MONITOR, { x: 0, y: 0, width: 3840, height: 2400, scale: 2.0 }]) {
    const placed = Model.windowRect([0, 0], [1920, 1200], monitor, SCREEN)
    assert.ok(Math.abs(placed.x) < EPSILON && Math.abs(placed.y) < EPSILON)
    assert.ok(Math.abs(placed.width - SCREEN.width) < EPSILON)
    assert.ok(Math.abs(placed.height - SCREEN.height) < EPSILON)
  }
})

test("a window keeps its place and proportions on screen", () => {
  // Dead centre of the screen at a quarter of its width.
  const placed = Model.windowRect([720, 450], [480, 300], MONITOR, SCREEN)
  assert.ok(Math.abs(placed.width / SCREEN.width - 0.25) < 1e-9)
  assert.ok(Math.abs((placed.x + placed.width / 2) - SCREEN.width / 2) < EPSILON)
  assert.ok(Math.abs((placed.y + placed.height / 2) - SCREEN.height / 2) < EPSILON)
})

test("a window on a monitor that is not at the origin is placed relative to it", () => {
  const right = { x: 1920, y: 0, width: 1920, height: 1200, scale: 1.0 }
  const placed = Model.windowRect([1920, 0], [1920, 1200], right, SCREEN)
  assert.ok(Math.abs(placed.x - SCREEN.x) < EPSILON, "the monitor's origin was not subtracted")
})

test("the swipe's endpoints are exact, so an open window rests on its slot", () => {
  const slot = Model.exposeRects(STACKED, ROOM, 16)[0]
  const real = Model.windowRect(STACKED[0].at, STACKED[0].size, MONITOR, SCREEN)
  assert.deepEqual(Model.lerpRect(real, slot, 0), real)
  assert.deepEqual(Model.lerpRect(real, slot, 1), slot)
  const half = Model.lerpRect(real, slot, 0.5)
  assert.equal(half.width, (real.width + slot.width) / 2)
})

test("finger travel past either end of the swipe is clamped", () => {
  assert.deepEqual([-0.5, 0, 0.5, 1, 1.5].map(Model.clamp01), [0, 0, 0.5, 1, 1])
})

// The five windows that were actually on workspace 1 when the overview was
// reported useless: all floating, all piled on the same middle of the screen.
const STACKED = [
  { at: [410, 216], size: [1100, 700] },
  { at: [377, 190], size: [1167, 751] },
  { at: [249, 39], size: [1670, 1052] },
  { at: [238, 41], size: [1428, 1063] },
  { at: [449, 40], size: [1313, 999] },
]

const overlap = (first, second) =>
  first.x < second.x + second.width - EPSILON && second.x < first.x + first.width - EPSILON
  && first.y < second.y + second.height - EPSILON && second.y < first.y + first.height - EPSILON

test("a real stack of overlapping windows really does overlap when drawn true to life", () => {
  const faithful = STACKED.map((w) => Model.windowRect(w.at, w.size, MONITOR, SCREEN))
  const collisions = faithful.flatMap((first, a) =>
    faithful.slice(a + 1).filter((second) => overlap(first, second)))
  // Guards the premise of exposeRects: without it this overview showed one window.
  assert.ok(collisions.length > 0, "the failing case no longer reproduces")
})

test("spread apart, no two windows cover each other", () => {
  for (const count of [1, 2, 3, 5, 8, 12]) {
    const windows = Array.from({ length: count }, (_, i) => STACKED[i % STACKED.length])
    const rects = Model.exposeRects(windows, ROOM, 16)
    assert.equal(rects.length, count, `${count} windows produced ${rects.length} slots`)
    for (let a = 0; a < count; a++) for (let b = a + 1; b < count; b++) {
      assert.ok(!overlap(rects[a], rects[b]), `${count} windows: ${a} still covers ${b}`)
    }
  }
})

test("every spread window stays inside the room it is given and keeps its shape", () => {
  const tile = { x: 120, y: 60, width: 800, height: 500 }
  const rects = Model.exposeRects(STACKED, tile, 16)
  for (const [index, rect] of rects.entries()) {
    assert.ok(rect.x >= tile.x - EPSILON && rect.y >= tile.y - EPSILON, `window ${index} escapes top/left`)
    assert.ok(rect.x + rect.width <= tile.x + tile.width + EPSILON, `window ${index} escapes right`)
    assert.ok(rect.y + rect.height <= tile.y + tile.height + EPSILON, `window ${index} escapes bottom`)
    assert.ok(rect.width > 0 && rect.height > 0, `window ${index} has no size`)
    const want = STACKED[index].size[0] / STACKED[index].size[1]
    assert.ok(Math.abs(rect.width / rect.height - want) < 1e-9, `window ${index} is distorted`)
  }
})

test("slots follow the windows' reading order, so a window lands near where it was", () => {
  const tile = { x: 0, y: 0, width: 900, height: 600 }
  const windows = [
    { at: [1500, 800], size: [300, 200] },  // bottom right -> last slot
    { at: [100, 50], size: [300, 200] },    // top left     -> first slot
    { at: [900, 50], size: [300, 200] },    // top right    -> second slot
  ]
  const rects = Model.exposeRects(windows, tile, 16)
  assert.ok(rects[1].y < rects[0].y, "the top-left window was not placed above the bottom-right one")
  assert.ok(rects[1].x < rects[2].x, "the top-left window was not placed left of the top-right one")
})

test("the spread is empty when there is nothing to spread", () => {
  assert.deepEqual(Model.exposeRects([], ROOM, 16), [])
})

test("windows fly from where they are to where they are going", () => {
  const from = Model.windowRect(STACKED[0].at, STACKED[0].size, MONITOR, SCREEN)
  const to = Model.exposeRects(STACKED, ROOM, 16)[0]
  assert.deepEqual(Model.lerpRect(from, to, 0), from, "a closed overview is not the real desktop")
  assert.deepEqual(Model.lerpRect(from, to, 1), to, "an open overview is not the spread layout")
})
