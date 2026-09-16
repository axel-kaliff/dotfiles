.pragma library

// Pure layout math for the overview: no QML types, no state.
//
// The shape is Hyprspace's (github.com/KZDKM/Hyprspace, src/Render.cpp
// `CHyprspaceWidget::draw`): a strip of miniature monitors, one per
// workspace, rather than the windows of one workspace spread into a grid.

// Which workspaces the strip shows. Hyprspace's rule, and the reason the
// strip is worth swiping to: every workspace in use on this monitor, every
// empty one below the highest so the numbering never jumps a gap, and one
// fresh workspace past the end -- that last slot is what turns "put this
// window somewhere new" into a drag instead of a keybind.
//
// `elsewhere` is what the other monitors already hold. A workspace living on
// another screen is not an empty slot this one can be sent to, and drawing it
// as one gave a second monitor a row of boxes that could never fill.
//
// Special workspaces (negative ids) belong in neither list: they are summoned,
// not switched to, so a slot in a left-to-right strip misrepresents them.
function stripWorkspaces(mine, elsewhere) {
  var taken = {}
  for (var e = 0; e < elsewhere.length; e++) taken[elsewhere[e]] = true

  var highest = 1
  for (var i = 0; i < mine.length; i++) {
    if (mine[i] > highest) highest = mine[i]
  }

  var ids = []
  for (var id = 1; id <= highest; id++) {
    if (!taken[id]) ids.push(id)
  }

  var fresh = highest + 1
  while (taken[fresh]) fresh++
  ids.push(fresh)
  return ids
}

// The strip itself: each workspace as a miniature of the whole monitor, laid
// out left to right and centred. Every box keeps the monitor's aspect, which
// is what lets a window be drawn at its true relative position inside one and
// still read as the desktop it stands for.
//
// A strip wider than the screen is panned by moving the whole thing, not by
// laying it out again: re-deriving these boxes hands the view a new model,
// and a rebuilt thumbnail loses the screen capture behind it. So `limit` is
// how far the pan may go in either direction, and the boxes never move.
function stripLayout(count, panel, panelHeight, margin) {
  var scale = panel.height > 0 ? (panelHeight - 2 * margin) / panel.height : 0
  var boxWidth = panel.width * scale
  var boxHeight = panel.height * scale
  var groupWidth = boxWidth * count + margin * Math.max(0, count - 1)

  var boxes = []
  for (var i = 0; i < count; i++) {
    boxes.push({
      x: (panel.width - groupWidth) / 2 + i * (boxWidth + margin),
      y: margin,
      width: boxWidth,
      height: boxHeight
    })
  }
  return { boxes: boxes, limit: Math.max((groupWidth - panel.width) / 2 + margin, 0) }
}

// Which workspace box a point is over, or -1. Hyprspace runs its click target
// and its drop target through the same hit test, so a release that lands on a
// workspace means the same thing whether or not a window came with it.
function boxAt(boxes, x, y) {
  for (var i = 0; i < boxes.length; i++) {
    var box = boxes[i]
    if (x >= box.x && x < box.x + box.width && y >= box.y && y < box.y + box.height) return i
  }
  return -1
}

// --- the expose ----------------------------------------------------------
//
// The other half of the overview, and the one Hyprspace has no answer for: it
// draws every window where it really sits, so on an untiled workspace a stack
// of overlapping windows photographs as one window -- exactly what the desktop
// already showed. The expose pulls the current workspace's windows apart until
// none covers another.

// Kept as square as the count allows, which is what keeps each window big
// enough to still be recognisable once they are spread out.
function gridShape(count) {
  if (count <= 0) return { cols: 1, rows: 1 }
  var cols = Math.ceil(Math.sqrt(count))
  return { cols: cols, rows: Math.ceil(count / cols) }
}

// The part that makes an overview worth opening: the windows are pulled apart
// until none covers another. Drawing them where they really sit is faithful
// and useless -- a stack of overlapping windows photographs as one window,
// which is the whole of what the desktop already showed.
//
// Slots are handed out in the windows' own reading order, so a window lands
// near where the eye last left it, and each keeps its true aspect ratio inside
// its slot so a thumbnail still looks like the window it stands for.
// Returns one rect per placement, in the order given.
function exposeRects(placements, area, gap) {
  var count = placements.length
  if (count === 0) return []

  var shape = gridShape(count)
  var cellWidth = (area.width - gap * (shape.cols - 1)) / shape.cols
  var cellHeight = (area.height - gap * (shape.rows - 1)) / shape.rows

  var order = []
  for (var i = 0; i < count; i++) order.push(i)
  order.sort(function (left, right) {
    var first = placements[left]
    var second = placements[right]
    var byRow = (first.at[1] + first.size[1] / 2) - (second.at[1] + second.size[1] / 2)
    // Windows within a whisker of the same height read as one row, so they are
    // ordered left to right rather than by a pixel of vertical difference.
    if (Math.abs(byRow) > 1) return byRow
    return (first.at[0] + first.size[0] / 2) - (second.at[0] + second.size[0] / 2)
  })

  var rects = new Array(count)
  for (var slot = 0; slot < count; slot++) {
    var index = order[slot]
    var row = Math.floor(slot / shape.cols)
    var col = slot % shape.cols
    var inRow = Math.min(shape.cols, count - row * shape.cols)
    var rowWidth = cellWidth * inRow + gap * (inRow - 1)
    var cellX = area.x + (area.width - rowWidth) / 2 + col * (cellWidth + gap)
    var cellY = area.y + row * (cellHeight + gap)

    var size = placements[index].size
    var aspect = size[1] > 0 ? size[0] / size[1] : 1
    var width = Math.min(cellWidth, cellHeight * aspect)
    var height = width / aspect

    rects[index] = {
      x: cellX + (cellWidth - width) / 2,
      y: cellY + (cellHeight - height) / 2,
      width: width,
      height: height
    }
  }
  return rects
}

// --- shared --------------------------------------------------------------

// Where a window really is, expressed inside `area`. `at` and `size` are
// Hyprland's logical layout coordinates, so the monitor's pixel size is
// divided by its scale before anything is compared against them.
function windowRect(at, size, monitor, area) {
  var logicalWidth = monitor.width / monitor.scale
  var logicalHeight = monitor.height / monitor.scale
  return {
    x: area.x + ((at[0] - monitor.x) / logicalWidth) * area.width,
    y: area.y + ((at[1] - monitor.y) / logicalHeight) * area.height,
    width: (size[0] / logicalWidth) * area.width,
    height: (size[1] / logicalHeight) * area.height
  }
}

// Whether a window lies where the compositor can draw it. One placed or
// scrolled outside its monitor yields no screen capture at all -- a scrolling
// layout puts windows past the viewport edge, and the thumbnail for one of
// those stays blank however long it is waited on. It is still worth drawing:
// a window you cannot see is exactly what an overview is for.
function onMonitor(at, size, monitor) {
  var right = monitor.x + monitor.width / monitor.scale
  var bottom = monitor.y + monitor.height / monitor.scale
  return at[0] < right && at[0] + size[0] > monitor.x
    && at[1] < bottom && at[1] + size[1] > monitor.y
}

function clamp(value, low, high) {
  return value < low ? low : value > high ? high : value
}

// Weighted rather than `from + (to - from) * t`: this form is exact at t=0
// and t=1, so a settled panel rests precisely where it belongs instead of a
// fraction of a pixel off it, which a thumbnail would show as blur.
function lerp(from, to, t) {
  return from * (1 - t) + to * t
}

// The desktop's motion is a spring (hypr/looknfeel.lua: appleSpring), and Qt
// has no spring easing, only bezier splines. This solves the underdamped
// spring x'' = -(k/m) x - (c/m) x' let go from one unit out and writes its
// path over `seconds` as the cubic Hermite spline Qt's BezierSpline easing
// takes, so the overview arrives with the same shape and pace as a window
// appearing. Qt requires the spline to end exactly at 1, so the tail is
// rescaled to: over 0.3s the appleSpring is within 0.4% of home, under a
// pixel anywhere on screen.
function springCurve(stiffness, damping, mass, seconds, segments) {
  var natural = Math.sqrt(stiffness / mass)
  var ratio = damping / (2 * Math.sqrt(stiffness * mass))
  var damped = natural * Math.sqrt(1 - ratio * ratio)
  var decay = ratio * natural
  function position(t) {
    return 1 - Math.exp(-decay * t) * (Math.cos(damped * t) + (decay / damped) * Math.sin(damped * t))
  }
  function velocity(t) {
    return Math.exp(-decay * t) * (natural * natural / damped) * Math.sin(damped * t)
  }
  var end = position(seconds)
  var curve = []
  for (var i = 0; i < segments; i++) {
    var u0 = i / segments
    var u1 = (i + 1) / segments
    var third = (u1 - u0) / 3
    var p0 = position(u0 * seconds) / end
    var p1 = position(u1 * seconds) / end
    var v0 = velocity(u0 * seconds) * seconds / end
    var v1 = velocity(u1 * seconds) * seconds / end
    curve.push(u0 + third, p0 + v0 * third, u1 - third, p1 - v1 * third, u1, p1)
  }
  return curve
}
