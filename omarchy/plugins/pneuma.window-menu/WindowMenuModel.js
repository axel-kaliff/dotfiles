.pragma library

// Pure row builder for the window menu: no QML types, no state.
//
// Hyprland's fullscreen property is 0 none, 1 maximized, 2 fullscreen, and both
// dispatchers toggle, so a window already in one of those states gets the row
// that takes it back out.

function rows(floating, pinned, fullscreen) {
  var out = []

  out.push({ label: floating ? "Tile" : "Float", action: "float", checked: floating })
  // Pin is Hyprland's "on every workspace, above the rest", and it only applies
  // to a floating window -- so the row also floats a tiled one on the way.
  out.push({ label: "Sticky (all workspaces)", action: "sticky", checked: pinned })

  out.push({ separator: true })

  out.push({ label: fullscreen === 1 ? "Unmaximize" : "Maximize", action: "maximize", checked: fullscreen === 1 })
  out.push({ label: fullscreen === 2 ? "Leave Fullscreen" : "Fullscreen", action: "fullscreen", checked: fullscreen === 2 })
  // Centring moves a window the layout owns nowhere, so it is offered only when
  // the window is free to be placed.
  if (floating) out.push({ label: "Centre", action: "center" })
  out.push({ label: "Minimize", action: "minimize" })

  out.push({ separator: true })
  out.push({ label: "Close", action: "close" })

  return out
}
