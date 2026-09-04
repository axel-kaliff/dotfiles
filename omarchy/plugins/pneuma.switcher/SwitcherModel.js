.pragma library

// Pure ordering helpers for the window switcher: no QML types, no state.

// `item` becomes the most recent entry; everything else keeps its order.
function moveToFront(order, item) {
  var out = [item]
  for (var i = 0; i < order.length; i++) {
    if (order[i] !== item) out.push(order[i])
  }
  return out
}

// Drop entries that are gone and append newcomers, in `present` order, at
// the back: a window that has never had focus is the least recent one.
function reconcile(order, present) {
  var alive = []
  for (var i = 0; i < order.length; i++) {
    if (present.indexOf(order[i]) !== -1) alive.push(order[i])
  }
  for (var j = 0; j < present.length; j++) {
    if (alive.indexOf(present[j]) === -1) alive.push(present[j])
  }
  return alive
}

function wrap(index, count) {
  if (count <= 0) return 0
  return ((index % count) + count) % count
}

// First index of the `max`-wide window of cards that keeps `index` in view.
function firstVisible(index, count, max) {
  if (count <= max) return 0
  return Math.max(0, Math.min(index - Math.floor(max / 2), count - max))
}
