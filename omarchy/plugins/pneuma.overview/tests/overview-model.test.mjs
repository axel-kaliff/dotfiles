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
  return { gridWorkspaces, gridShape, tileRect, windowRect, exposeRects, clamp01, lerp, lerpRect }`)()

const MONITOR = { x: 0, y: 0, width: 1920, height: 1200, scale: 1.0 }
const PANEL = { width: 1920, height: 1200 }
const ASPECT = PANEL.width / PANEL.height
const EPSILON = 0.01

const layout = (count) => Array.from({ length: count }, (_, index) =>
  Model.tileRect(index, count, PANEL.width, PANEL.height, 24, 80, ASPECT))

test("the grid stays as square as the count allows", () => {
  assert.deepEqual([1, 2, 3, 4, 5, 6, 7].map((n) => Model.gridShape(n)), [
    { cols: 1, rows: 1 }, { cols: 2, rows: 1 }, { cols: 2, rows: 2 }, { cols: 2, rows: 2 },
    { cols: 3, rows: 2 }, { cols: 3, rows: 2 }, { cols: 3, rows: 3 },
  ])
  assert.deepEqual(Model.gridShape(0), { cols: 1, rows: 1 })
})

test("tiles stay on screen, keep the monitor's aspect, and never overlap", () => {
  for (let count = 1; count <= 9; count++) {
    const tiles = layout(count)
    for (const [index, tile] of tiles.entries()) {
      assert.ok(tile.x >= -EPSILON && tile.y >= -EPSILON, `tile ${index} of ${count} starts off screen`)
      assert.ok(tile.x + tile.width <= PANEL.width + EPSILON, `tile ${index} of ${count} runs off the right`)
      assert.ok(tile.y + tile.height <= PANEL.height + EPSILON, `tile ${index} of ${count} runs off the bottom`)
      assert.ok(Math.abs(tile.width / tile.height - ASPECT) < 1e-9, `tile ${index} of ${count} is not a true miniature`)
    }
    for (let a = 0; a < count; a++) for (let b = a + 1; b < count; b++) {
      const [first, second] = [tiles[a], tiles[b]]
      const overlaps = first.x < second.x + second.width - EPSILON && second.x < first.x + first.width - EPSILON
        && first.y < second.y + second.height - EPSILON && second.y < first.y + first.height - EPSILON
      assert.ok(!overlaps, `tiles ${a}/${b} of ${count} overlap`)
    }
  }
})

test("a short last row is centred rather than left hanging", () => {
  const tiles = layout(5)  // three columns, then two
  assert.ok(tiles[3].x > tiles[0].x + EPSILON)
  assert.ok(Math.abs((tiles[3].x - tiles[0].x) - (tiles[2].x - tiles[4].x)) < EPSILON)
})

test("a full-screen window fills its tile, whatever the monitor scale", () => {
  const tile = layout(4)[0]
  for (const monitor of [MONITOR, { x: 0, y: 0, width: 3840, height: 2400, scale: 2.0 }]) {
    const placed = Model.windowRect([0, 0], [1920, 1200], monitor, tile)
    assert.ok(Math.abs(placed.x - tile.x) < EPSILON && Math.abs(placed.y - tile.y) < EPSILON)
    assert.ok(Math.abs(placed.width - tile.width) < EPSILON && Math.abs(placed.height - tile.height) < EPSILON)
  }
})

test("a window keeps its place and proportions inside the tile", () => {
  const tile = layout(4)[0]
  // Dead centre of the screen at a quarter of its width.
  const placed = Model.windowRect([720, 450], [480, 300], MONITOR, tile)
  assert.ok(Math.abs(placed.width / tile.width - 0.25) < 1e-9)
  assert.ok(Math.abs((placed.x + placed.width / 2) - (tile.x + tile.width / 2)) < EPSILON)
  assert.ok(Math.abs((placed.y + placed.height / 2) - (tile.y + tile.height / 2)) < EPSILON)
})

test("a window on a monitor that is not at the origin is placed relative to it", () => {
  const tile = layout(4)[0]
  const right = { x: 1920, y: 0, width: 1920, height: 1200, scale: 1.0 }
  const placed = Model.windowRect([1920, 0], [1920, 1200], right, tile)
  assert.ok(Math.abs(placed.x - tile.x) < EPSILON, "the monitor's origin was not subtracted")
})

test("the swipe's endpoints are exact, so an open tile rests on its slot", () => {
  const tile = layout(4)[0]
  const screen = { x: 0, y: 0, width: PANEL.width, height: PANEL.height }
  assert.deepEqual(Model.lerpRect(screen, tile, 0), screen)
  assert.deepEqual(Model.lerpRect(screen, tile, 1), tile)
  const half = Model.lerpRect(screen, tile, 0.5)
  assert.equal(half.width, (screen.width + tile.width) / 2)
})

test("finger travel past either end of the swipe is clamped", () => {
  assert.deepEqual([-0.5, 0, 0.5, 1, 1.5].map(Model.clamp01), [0, 0, 0.5, 1, 1])
})

test("specials, other monitors, and unplaced workspaces stay out of the grid", () => {
  const workspaces = [
    { id: 2, monitor: { name: "eDP-1" } },
    { id: 1, monitor: { name: "eDP-1" } },
    { id: -98, monitor: { name: "eDP-1" } },  // special:music
    { id: 3, monitor: { name: "HDMI-A-1" } },
    { id: 4, monitor: null },
  ]
  assert.deepEqual(Model.gridWorkspaces(workspaces, "eDP-1").map((w) => w.id), [1, 2])
  assert.deepEqual(Model.gridWorkspaces([], "eDP-1"), [])
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
  const tile = { x: 0, y: 0, width: 1740, height: 1088 }
  const faithful = STACKED.map((w) => Model.windowRect(w.at, w.size, MONITOR, tile))
  const collisions = faithful.flatMap((first, a) =>
    faithful.slice(a + 1).filter((second) => overlap(first, second)))
  // Guards the premise of exposeRects: without it this overview showed one window.
  assert.ok(collisions.length > 0, "the failing case no longer reproduces")
})

test("spread apart, no two windows cover each other", () => {
  for (const count of [1, 2, 3, 5, 8, 12]) {
    const windows = Array.from({ length: count }, (_, i) => STACKED[i % STACKED.length])
    const tile = { x: 0, y: 0, width: 1740, height: 1088 }
    const rects = Model.exposeRects(windows, tile, 10)
    assert.equal(rects.length, count, `${count} windows produced ${rects.length} slots`)
    for (let a = 0; a < count; a++) for (let b = a + 1; b < count; b++) {
      assert.ok(!overlap(rects[a], rects[b]), `${count} windows: ${a} still covers ${b}`)
    }
  }
})

test("every spread window stays inside its tile and keeps its shape", () => {
  const tile = { x: 120, y: 60, width: 800, height: 500 }
  const rects = Model.exposeRects(STACKED, tile, 10)
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
  const rects = Model.exposeRects(windows, tile, 10)
  assert.ok(rects[1].y < rects[0].y, "the top-left window was not placed above the bottom-right one")
  assert.ok(rects[1].x < rects[2].x, "the top-left window was not placed left of the top-right one")
})

test("the spread is empty when there is nothing to spread", () => {
  assert.deepEqual(Model.exposeRects([], { x: 0, y: 0, width: 800, height: 500 }, 10), [])
})

test("windows fly from where they are to where they are going", () => {
  const tile = { x: 0, y: 0, width: 1740, height: 1088 }
  const from = Model.windowRect(STACKED[0].at, STACKED[0].size, MONITOR, tile)
  const to = Model.exposeRects(STACKED, tile, 10)[0]
  assert.deepEqual(Model.lerpRect(from, to, 0), from, "a closed overview is not the real desktop")
  assert.deepEqual(Model.lerpRect(from, to, 1), to, "an open overview is not the spread layout")
})
