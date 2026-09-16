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
  return { stripWorkspaces, stripLayout, boxAt, gridShape, exposeRects, windowRect, onMonitor, clamp, lerp }`)()

const MONITOR = { x: 0, y: 0, width: 1920, height: 1200, scale: 1.0 }
const PANEL = { width: 1920, height: 1200 }
const PANEL_HEIGHT = 250
const MARGIN = 12
const EPSILON = 0.01

const strip = (count) => Model.stripLayout(count, PANEL, PANEL_HEIGHT, MARGIN)

test("the strip shows every workspace in use with no gap in the numbering", () => {
  assert.deepEqual(Model.stripWorkspaces([1, 3, 5], []), [1, 2, 3, 4, 5, 6])
  assert.deepEqual(Model.stripWorkspaces([2], []), [1, 2, 3])
})

test("the strip always ends on a free workspace, so a drag has somewhere new to go", () => {
  for (const mine of [[], [1], [1, 2, 3], [4]]) {
    const ids = Model.stripWorkspaces(mine, [])
    assert.ok(!mine.includes(ids[ids.length - 1]),
      `the last slot ${ids[ids.length - 1]} is already in use`)
  }
})

test("a workspace that lives on another monitor is not an empty slot on this one", () => {
  // The real two-monitor case: this screen holds only workspace 4, while
  // 1, 2, 3 and 9 are on the other one. Filling the gap below 4 with those
  // gave this monitor three boxes that could never fill.
  assert.deepEqual(Model.stripWorkspaces([4], [1, 2, 3, 9]), [4, 5])
  assert.deepEqual(Model.stripWorkspaces([1, 2, 3, 9], [4]), [1, 2, 3, 5, 6, 7, 8, 9, 10])
})

test("the fresh slot at the end skips past a workspace another monitor holds", () => {
  assert.deepEqual(Model.stripWorkspaces([1], [2, 3]), [1, 4])
})

test("special workspaces get no slot in a left-to-right strip", () => {
  assert.deepEqual(Model.stripWorkspaces([-99, 1], []), [1, 2])
})

test("a workspace box is as tall as the panel leaves room for and shaped like the monitor", () => {
  for (const count of [1, 3, 9]) {
    for (const box of strip(count).boxes) {
      assert.ok(Math.abs(box.height - (PANEL_HEIGHT - 2 * MARGIN)) < EPSILON)
      assert.ok(Math.abs(box.width / box.height - PANEL.width / PANEL.height) < 1e-9,
        "a miniature that is not the monitor's shape misplaces every window in it")
    }
  }
})

test("boxes sit in a row one margin apart", () => {
  const boxes = strip(4).boxes
  for (let i = 1; i < boxes.length; i++) {
    assert.ok(Math.abs(boxes[i].x - (boxes[i - 1].x + boxes[i - 1].width + MARGIN)) < EPSILON)
    assert.equal(boxes[i].y, boxes[0].y)
  }
})

test("a strip that fits is centred and offers no pan", () => {
  const boxes = strip(3).boxes
  const left = boxes[0].x
  const right = boxes[boxes.length - 1].x + boxes[boxes.length - 1].width
  assert.ok(Math.abs((left + right) / 2 - PANEL.width / 2) < EPSILON, "not centred")
  // Nothing is off screen to reach, so a pan could only drag it out of sight.
  assert.equal(strip(3).limit, 0)
})

test("a strip that overflows may be panned as far as it hangs off the screen", () => {
  const laid = strip(20)
  const group = laid.boxes[19].x + laid.boxes[19].width - laid.boxes[0].x
  assert.ok(group > PANEL.width, "20 workspaces should not fit on one screen")
  assert.ok(Math.abs(laid.limit - ((group - PANEL.width) / 2 + MARGIN)) < EPSILON)

  // Panned all the way, the far box has come past the screen edge.
  assert.ok(laid.boxes[19].x + laid.boxes[19].width - laid.limit < PANEL.width)
  assert.ok(laid.boxes[0].x + laid.limit > 0)
})

test("the hit test finds the box under a point, and nothing between them", () => {
  const boxes = strip(4).boxes
  const middleOf = (box) => [box.x + box.width / 2, box.y + box.height / 2]

  boxes.forEach((box, index) => assert.equal(Model.boxAt(boxes, ...middleOf(box)), index))
  // The margin between two boxes belongs to neither.
  assert.equal(Model.boxAt(boxes, boxes[0].x + boxes[0].width + MARGIN / 2, boxes[0].y + 10), -1)
  assert.equal(Model.boxAt(boxes, boxes[0].x, boxes[0].y + boxes[0].height + 1), -1)
})

test("a full-screen window fills its workspace box, whatever the monitor scale", () => {
  const box = strip(3).boxes[1]
  for (const monitor of [MONITOR, { x: 0, y: 0, width: 3840, height: 2400, scale: 2.0 }]) {
    const placed = Model.windowRect([0, 0], [1920, 1200], monitor, box)
    assert.ok(Math.abs(placed.x - box.x) < EPSILON && Math.abs(placed.y - box.y) < EPSILON)
    assert.ok(Math.abs(placed.width - box.width) < EPSILON)
    assert.ok(Math.abs(placed.height - box.height) < EPSILON)
  }
})

test("a window keeps its place and proportions inside the miniature", () => {
  const box = strip(3).boxes[0]
  // Dead centre of the monitor at a quarter of its width.
  const placed = Model.windowRect([720, 450], [480, 300], MONITOR, box)
  assert.ok(Math.abs(placed.width / box.width - 0.25) < 1e-9)
  assert.ok(Math.abs((placed.x + placed.width / 2) - (box.x + box.width / 2)) < EPSILON)
  assert.ok(Math.abs((placed.y + placed.height / 2) - (box.y + box.height / 2)) < EPSILON)
})

test("a window on a monitor that is not at the origin is placed relative to it", () => {
  const box = strip(3).boxes[0]
  const right = { x: 1920, y: 0, width: 1920, height: 1200, scale: 1.0 }
  const placed = Model.windowRect([1920, 0], [1920, 1200], right, box)
  assert.ok(Math.abs(placed.x - box.x) < EPSILON, "the monitor's origin was not subtracted")
})

test("the slide's endpoints are exact, so a settled panel rests where it belongs", () => {
  assert.equal(Model.lerp(-250, 0, 0), -250)
  assert.equal(Model.lerp(-250, 0, 1), 0)
})

test("clamp holds a value inside its bounds", () => {
  assert.deepEqual([-1, 0, 0.5, 1, 2].map((n) => Model.clamp(n, 0, 1)), [0, 0, 0.5, 1, 1])
})

// --- the expose ----------------------------------------------------------

const SCREEN = { x: 0, y: 0, width: PANEL.width, height: PANEL.height }
const ROOM = { x: 56, y: 56, width: PANEL.width - 112, height: PANEL.height - 112 }
// Three windows stacked almost exactly on top of one another: the case the
// expose exists for, and the one the strip cannot help with.
const STACKED = [
  { at: [100, 100], size: [900, 600] },
  { at: [120, 130], size: [900, 600] },
  { at: [140, 160], size: [900, 600] },
]

test("the grid stays as square as the count allows", () => {
  assert.deepEqual([1, 2, 3, 4, 5, 6, 7].map((n) => Model.gridShape(n)), [
    { cols: 1, rows: 1 }, { cols: 2, rows: 1 }, { cols: 2, rows: 2 }, { cols: 2, rows: 2 },
    { cols: 3, rows: 2 }, { cols: 3, rows: 2 }, { cols: 3, rows: 3 },
  ])
  assert.deepEqual(Model.gridShape(0), { cols: 1, rows: 1 })
})

test("windows that covered each other come apart so none covers another", () => {
  const rects = Model.exposeRects(STACKED, ROOM, 16)
  assert.equal(rects.length, STACKED.length)
  for (let i = 0; i < rects.length; i++) {
    for (let j = i + 1; j < rects.length; j++) {
      const a = rects[i], b = rects[j]
      const overlaps = a.x < b.x + b.width && b.x < a.x + a.width
        && a.y < b.y + b.height && b.y < a.y + a.height
      assert.ok(!overlaps, `spread windows ${i} and ${j} still overlap`)
    }
  }
})

test("a spread window keeps its own proportions and stays inside the room", () => {
  for (const rect of Model.exposeRects(STACKED, ROOM, 16)) {
    assert.ok(Math.abs(rect.width / rect.height - 900 / 600) < 1e-9,
      "a thumbnail that is not the window's shape stops looking like it")
    assert.ok(rect.x >= ROOM.x - EPSILON && rect.y >= ROOM.y - EPSILON)
    assert.ok(rect.x + rect.width <= ROOM.x + ROOM.width + EPSILON)
    assert.ok(rect.y + rect.height <= ROOM.y + ROOM.height + EPSILON)
  }
})

test("slots are handed out in reading order, so a window lands near where it was", () => {
  const corners = [
    { at: [1400, 800], size: [400, 300] },  // bottom right
    { at: [100, 100], size: [400, 300] },   // top left
    { at: [1400, 100], size: [400, 300] },  // top right
    { at: [100, 800], size: [400, 300] },   // bottom left
  ]
  const rects = Model.exposeRects(corners, ROOM, 16)
  assert.ok(rects[1].y < rects[3].y, "the top-left window did not stay above the bottom-left one")
  assert.ok(rects[1].x < rects[2].x, "the top-left window did not stay left of the top-right one")
})

test("an empty workspace spreads to nothing rather than dividing by zero", () => {
  assert.deepEqual(Model.exposeRects([], ROOM, 16), [])
})

test("a window scrolled off its monitor is known to be uncapturable", () => {
  // The real case: a 3440-wide monitor at x=-760, and a scrolling layout that
  // parks the third window at 3763 -- past the right edge at 2680. Its capture
  // never arrives, so the overview must not wait for it.
  const wide = { x: -760, y: -1440, width: 3440, height: 1440, scale: 1.0 }
  assert.equal(Model.onMonitor([-745, -1399], [2823, 1384], wide), true)
  assert.equal(Model.onMonitor([2092, -1399], [1657, 1384], wide), true, "straddles the edge")
  assert.equal(Model.onMonitor([3763, -1399], [1664, 1384], wide), false)
})

test("a window on a hidden workspace still counts, being within the monitor", () => {
  // Hidden is not the same as off-monitor: Hyprland renders a hidden window
  // offscreen on request, so its thumbnail does arrive.
  assert.equal(Model.onMonitor([0, 0], [1920, 1200], MONITOR), true)
})

// The desktop's spring: hypr/looknfeel.lua's appleSpring, over the 300ms the
// overview takes to open.
const SPRING = Model.springCurve(520, 38, 1, 0.3, 10)

test("the spring is a bezier spline Qt accepts: six numbers a segment, ending exactly at 1,1", () => {
  assert.equal(SPRING.length, 60)
  assert.equal(SPRING[58], 1)
  assert.equal(SPRING[59], 1)
})

test("the spline runs forward in time: every x, control points included, follows the last", () => {
  for (let i = 0; i + 4 < SPRING.length; i += 2) {
    const x = SPRING[i]
    const next = SPRING[i + 2]
    assert.ok(next > x, `x at ${i + 2} (${next}) does not follow ${x}`)
  }
})

test("the spring leaves from rest and never swings past home by more than a pixel would show", () => {
  // From rest: the first control point sits on the floor, so nothing jumps.
  assert.equal(SPRING[1], 0)
  for (let i = 1; i < SPRING.length; i += 2) {
    assert.ok(SPRING[i] >= 0 && SPRING[i] <= 1.02, `y at ${i} is ${SPRING[i]}`)
  }
})

test("the spring arrives at the desktop's pace: most of the way by half time, home by the last fifth", () => {
  // Segment endpoints are every 30ms: the fifth is 150ms in, the eighth 240ms.
  const at = (segment) => SPRING[segment * 6 - 1]
  assert.ok(at(5) > 0.9, `at 150ms: ${at(5)}`)
  assert.ok(Math.abs(at(8) - 1) < 0.01, `at 240ms: ${at(8)}`)
})
