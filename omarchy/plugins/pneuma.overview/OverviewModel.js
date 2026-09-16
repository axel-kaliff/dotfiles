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

function clamp(value, low, high) {
  return value < low ? low : value > high ? high : value
}

// Weighted rather than `from + (to - from) * t`: this form is exact at t=0
// and t=1, so a settled panel rests precisely where it belongs instead of a
// fraction of a pixel off it, which a thumbnail would show as blur.
function lerp(from, to, t) {
  return from * (1 - t) + to * t
}
