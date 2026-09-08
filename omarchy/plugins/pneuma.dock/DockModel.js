.pragma library

// Pure model helpers for the dock: no QML types, no state.

function normalize(appId) {
  return String(appId || "").toLowerCase()
}

// One row per application: the pinned apps first, in the order they were
// pinned, then whatever else is running. A pinned app with no toplevels is a
// launcher; the same row becomes a task the moment it opens a window, which is
// what keeps an app from jumping sideways in the dock when it starts.
function rows(pinnedIds, toplevels) {
  var out = []
  var indexOf = {}

  function row(appId, pinned) {
    if (indexOf[appId] === undefined) {
      indexOf[appId] = out.length
      out.push({ appId: appId, pinned: pinned, toplevels: [] })
    }
    return out[indexOf[appId]]
  }

  for (var i = 0; i < pinnedIds.length; i++) {
    row(normalize(pinnedIds[i]), true)
  }

  for (var j = 0; j < toplevels.length; j++) {
    var appId = normalize(toplevels[j].appId)
    if (appId === "") continue
    row(appId, false).toplevels.push(toplevels[j])
  }

  return out
}

// A divider goes where the pinned apps stop and the merely-running ones start.
function startsRunningSection(rowList, index) {
  return index > 0 && !rowList[index].pinned && rowList[index - 1].pinned
}

function isPinned(pinnedIds, appId) {
  var id = normalize(appId)
  for (var i = 0; i < pinnedIds.length; i++) {
    if (normalize(pinnedIds[i]) === id) return true
  }
  return false
}

function togglePin(pinnedIds, appId) {
  var id = normalize(appId)
  var kept = []
  for (var i = 0; i < pinnedIds.length; i++) {
    if (normalize(pinnedIds[i]) !== id) kept.push(pinnedIds[i])
  }
  return kept.length === pinnedIds.length ? pinnedIds.concat([id]) : kept
}

// The window a click should land on: the first one that isn't already focused,
// so repeated clicks walk an app's windows instead of sticking on the front
// one. Falls back to the only window there is.
function nextWindow(toplevels, active) {
  for (var i = 0; i < toplevels.length; i++) {
    if (toplevels[i] !== active) return toplevels[i]
  }
  return toplevels.length > 0 ? toplevels[0] : null
}
