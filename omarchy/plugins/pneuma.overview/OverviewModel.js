.pragma library

// Pure layout math for the overview: no QML types, no state.

// The workspaces that belong in the grid: the numbered ones on `monitorName`,
// in id order. Specials have negative ids and stay out -- they are reached by
// their own gesture, not through here.
function gridWorkspaces(workspaces, monitorName) {
  var out = []
  for (var i = 0; i < workspaces.length; i++) {
    var workspace = workspaces[i]
    if (workspace.id < 0) continue
    if (!workspace.monitor || String(workspace.monitor.name) !== monitorName) continue
    out.push(workspace)
  }
  out.sort(function (a, b) { return a.id - b.id })
  return out
}

// Kept as square as the count allows, which is what makes a tile big enough
// for its thumbnails to still be recognisable.
function gridShape(count) {
  if (count <= 0) return { cols: 1, rows: 1 }
  var cols = Math.ceil(Math.sqrt(count))
  return { cols: cols, rows: Math.ceil(count / cols) }
}

// Where tile `index` sits once the overview is fully open. Tiles keep the
// monitor's aspect ratio so a thumbnail is a true miniature of the screen,
// and a short last row is centred rather than left hanging.
function tileRect(index, count, panelWidth, panelHeight, gap, margin, aspect) {
  var shape = gridShape(count)
  var availableWidth = panelWidth - margin * 2
  var availableHeight = panelHeight - margin * 2
  var cellWidth = (availableWidth - gap * (shape.cols - 1)) / shape.cols
  var cellHeight = (availableHeight - gap * (shape.rows - 1)) / shape.rows

  var width = Math.min(cellWidth, cellHeight * aspect)
  var height = width / aspect

  var row = Math.floor(index / shape.cols)
  var col = index % shape.cols
  var inRow = Math.min(shape.cols, count - row * shape.cols)
  var rowWidth = width * inRow + gap * (inRow - 1)
  var gridHeight = height * shape.rows + gap * (shape.rows - 1)

  return {
    x: (panelWidth - rowWidth) / 2 + col * (width + gap),
    y: (panelHeight - gridHeight) / 2 + row * (height + gap),
    width: width,
    height: height
  }
}

// A window's place inside a tile. `at` and `size` are Hyprland's logical
// layout coordinates, so the monitor's pixel size is divided by its scale
// before anything is compared against them.
function windowRect(at, size, monitor, tile) {
  var logicalWidth = monitor.width / monitor.scale
  var logicalHeight = monitor.height / monitor.scale
  return {
    x: tile.x + ((at[0] - monitor.x) / logicalWidth) * tile.width,
    y: tile.y + ((at[1] - monitor.y) / logicalHeight) * tile.height,
    width: (size[0] / logicalWidth) * tile.width,
    height: (size[1] / logicalHeight) * tile.height
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

// The active workspace's tile grows out of the real screen it is covering, so
// at progress 0 it lines up pixel for pixel with the desktop behind it.
function lerpRect(from, to, t) {
  return {
    x: lerp(from.x, to.x, t),
    y: lerp(from.y, to.y, t),
    width: lerp(from.width, to.width, t),
    height: lerp(from.height, to.height, t)
  }
}
