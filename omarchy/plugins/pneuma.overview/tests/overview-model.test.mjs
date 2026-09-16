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
  return { stripWorkspaces, stripLayout, boxAt, windowRect, clamp, lerp }`)()

const MONITOR = { x: 0, y: 0, width: 1920, height: 1200, scale: 1.0 }
const PANEL = { width: 1920, height: 1200 }
const PANEL_HEIGHT = 250
const MARGIN = 12
const EPSILON = 0.01

const strip = (count, scroll = 0) => Model.stripLayout(count, PANEL, PANEL_HEIGHT, MARGIN, scroll)

test("the strip shows every workspace in use with no gap in the numbering", () => {
  assert.deepEqual(Model.stripWorkspaces([1, 3, 5]), [1, 2, 3, 4, 5, 6])
  assert.deepEqual(Model.stripWorkspaces([2]), [1, 2, 3])
})

test("the strip always ends on a free workspace, so a drag has somewhere new to go", () => {
  for (const occupied of [[], [1], [1, 2, 3], [4]]) {
    const ids = Model.stripWorkspaces(occupied)
    assert.ok(!occupied.includes(ids[ids.length - 1]),
      `the last slot ${ids[ids.length - 1]} is already in use`)
  }
})

test("special workspaces get no slot in a left-to-right strip", () => {
  assert.deepEqual(Model.stripWorkspaces([-99, 1]), [1, 2])
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

test("a strip that fits is centred and cannot be panned", () => {
  const boxes = strip(3).boxes
  const left = boxes[0].x
  const right = boxes[boxes.length - 1].x + boxes[boxes.length - 1].width
  assert.ok(Math.abs((left + right) / 2 - PANEL.width / 2) < EPSILON, "not centred")
  // Nothing is off screen to reach, so a pan would only drag it out of sight.
  // `===` rather than strictEqual: a clamp to a zero limit yields -0 from the
  // negative side, which positions identically and differs only to Object.is.
  assert.ok(strip(3, 900).scroll === 0)
  assert.ok(strip(3, -900).scroll === 0)
})

test("a strip that overflows pans, but only as far as there is something to reach", () => {
  const overflowing = strip(20, 0)
  const group = overflowing.boxes[19].x + overflowing.boxes[19].width - overflowing.boxes[0].x
  assert.ok(group > PANEL.width, "20 workspaces should not fit on one screen")

  const limit = (group - PANEL.width) / 2 + MARGIN
  assert.ok(Math.abs(strip(20, 1e6).scroll - limit) < EPSILON)
  assert.ok(Math.abs(strip(20, -1e6).scroll + limit) < EPSILON)
  assert.equal(strip(20, 40).scroll, 40)
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
