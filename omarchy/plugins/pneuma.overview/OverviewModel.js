.pragma library

// Pure layout math for the overview: no QML types, no state.
//
// The shape is Hyprspace's (github.com/KZDKM/Hyprspace, src/Render.cpp
// `CHyprspaceWidget::draw`): a strip of miniature monitors, one per
// workspace, rather than the windows of one workspace spread into a grid.

// Which workspaces the strip shows. Hyprspace's rule, and the reason the
// strip is worth swiping to: every workspace in use, every empty one below
// the highest so the numbering never jumps a gap, and one fresh workspace
// past the end -- that last slot is what turns "put this window somewhere
// new" into a drag instead of a keybind.
//
// Special workspaces (negative ids) are left out: they are summoned, not
// switched to, so a slot in a left-to-right strip misrepresents them.
function stripWorkspaces(occupied) {
  var highest = 1
  for (var i = 0; i < occupied.length; i++) {
    if (occupied[i] > highest) highest = occupied[i]
  }

  var ids = []
  // Through the first free id past the last one in use, so the strip always
  // ends on an empty workspace whatever the gaps below it.
  for (var id = 1; id <= highest + 1; id++) ids.push(id)
  return ids
}

// The strip itself: each workspace as a miniature of the whole monitor, laid
// out left to right and centred. Every box keeps the monitor's aspect, which
// is what lets a window be drawn at its true relative position inside one and
// still read as the desktop it stands for.
//
// `scroll` is returned clamped rather than trusted, so a strip that already
// fits on screen cannot be panned out from under the pointer.
function stripLayout(count, panel, panelHeight, margin, scroll) {
  var scale = panel.height > 0 ? (panelHeight - 2 * margin) / panel.height : 0
  var boxWidth = panel.width * scale
  var boxHeight = panel.height * scale
  var groupWidth = boxWidth * count + margin * Math.max(0, count - 1)

  var limit = Math.max((groupWidth - panel.width) / 2 + margin, 0)
  var panned = clamp(scroll, -limit, limit)

  var boxes = []
  for (var i = 0; i < count; i++) {
    boxes.push({
      x: panned + (panel.width - groupWidth) / 2 + i * (boxWidth + margin),
      y: margin,
      width: boxWidth,
      height: boxHeight
    })
  }
  return { boxes: boxes, scroll: panned }
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
