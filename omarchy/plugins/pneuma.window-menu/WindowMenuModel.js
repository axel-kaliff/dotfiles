.pragma library

// Pure row builder for the window menu: no QML types, no state.
//
// Hyprland's fullscreen property is 0 none, 1 maximized, 2 fullscreen, and both
// dispatchers toggle, so a window already in one of those states gets the row
// that takes it back out.

function rows(floating, pinned, fullscreen, stackSize, stackLocked) {
  var out = []
  var stacked = stackSize > 0

  out.push({ label: floating ? "Tile" : "Float", action: "float", checked: floating })
  // Pin is Hyprland's "on every workspace, above the rest", and it only applies
  // to a floating window -- so the row also floats a tiled one on the way.
  out.push({ label: "Sticky (all workspaces)", action: "sticky", checked: pinned })

  // Stacking is Hyprland's window groups: several windows sharing one tile,
  // switched by the tabs drawn above them, which is what COSMIC calls a stack.
  // The tab bar is only drawn while the stack is tiled, so "Stack" tiles a
  // floating window on the way in.
  out.push({ label: stacked ? "Unstack" : "Stack", action: "stack", checked: stacked })
  // "Unstack" dissolves the whole stack, so taking one window out needs its own
  // row -- Hyprland has no drag-a-tab-out gesture to fall back on.
  if (stackSize > 1) out.push({ label: "Move out of stack", action: "stack-remove" })
  // New windows join the focused stack by themselves (group:auto_group), which
  // is how a stack grows by surprise. Locking it is the way to stop that.
  if (stacked) out.push({ label: "Lock stack", action: "stack-lock", checked: stackLocked })

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
