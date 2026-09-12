.pragma library

// Pure layout math for the overview: no QML types, no state.

// Kept as square as the count allows, which is what keeps each window big
// enough to still be recognisable once they are spread out.
function gridShape(count) {
  if (count <= 0) return { cols: 1, rows: 1 }
  var cols = Math.ceil(Math.sqrt(count))
  return { cols: cols, rows: Math.ceil(count / cols) }
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

function clamp01(value) {
  return value < 0 ? 0 : value > 1 ? 1 : value
}

// Weighted rather than `from + (to - from) * t`: this form is exact at t=0
// and t=1, so an open tile rests precisely on its grid slot instead of a
// fraction of a pixel off it, which a thumbnail would show as blur.
function lerp(from, to, t) {
  return from * (1 - t) + to * t
}

// Each window flies from where it actually sits to its slot, so at progress 0
// the overview lines up pixel for pixel with the desktop behind it.
function lerpRect(from, to, t) {
  return {
    x: lerp(from.x, to.x, t),
    y: lerp(from.y, to.y, t),
    width: lerp(from.width, to.width, t),
    height: lerp(from.height, to.height, t)
  }
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
