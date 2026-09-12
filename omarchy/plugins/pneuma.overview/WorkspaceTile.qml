import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import qs.Commons
import qs.Ui
import "OverviewModel.js" as Model

// One workspace in the overview: every window on it as a live thumbnail,
// pulled far enough apart that none covers another. Swiping flies each window
// from where it actually sits to its slot, so the tile comes apart out of the
// real desktop rather than replacing it.
//
// Nothing here resizes while a swipe is running. The tile is built once at the
// size it will rest at and the parent scales it; every thumbnail is likewise
// fixed and moved by transform. That is not a micro-optimisation -- resizing
// the tile re-derives `placed`, which hands the Repeater a new array, which
// destroys and rebuilds every delegate and restarts every screen capture, on
// every frame of the gesture. It reads as lag and flicker.
Item {
  id: tile

  required property var workspace
  required property var monitor
  required property bool capturing
  required property bool active
  required property real progress

  signal windowChosen(var toplevel)
  signal chosen()

  // Windows come apart ahead of the swipe rather than in step with it: eased
  // this way they are already legible around the halfway mark, where a linear
  // separation still has them piled up at exactly the moment you are looking.
  readonly property real separation: 1 - Math.pow(1 - tile.progress, 3)
  readonly property bool hovered: hoverTracker.hovered
  readonly property var frameBox: ({ x: 0, y: 0, width: tile.width, height: tile.height })

  // Each window with both of its boxes worked out in the same pass: where it
  // really is, and the slot it spreads into. Deriving them together is what
  // makes it impossible to index one apart from the other.
  //
  // A window Hyprland has not described yet is simply not in the list --
  // `lastIpcObject` is an empty, and so still truthy, map until it has been,
  // which is why the geometry itself is what gets checked.
  readonly property var placed: {
    if (!tile.monitor || tile.width <= 0) return []
    var all = tile.workspace && tile.workspace.toplevels ? tile.workspace.toplevels.values : []

    var described = []
    for (var i = 0; i < all.length; i++) {
      var box = all[i].lastIpcObject
      if (!box || !box.at || !box.size) continue
      described.push({ toplevel: all[i], at: box.at, size: box.size })
    }

    var spread = Model.exposeRects(described, tile.frameBox, Style.space(10))
    for (var j = 0; j < described.length; j++) {
      described[j].actual = Model.windowRect(described[j].at, described[j].size,
        tile.monitor, tile.frameBox)
      described[j].target = spread[j]
    }
    return described
  }

  HoverHandler { id: hoverTracker }

  // A click on the part of a tile no window covers means "just take me there".
  MouseArea {
    anchors.fill: parent
    cursorShape: Qt.PointingHandCursor
    onClicked: tile.chosen()
  }

  ClippingRectangle {
    id: frame

    anchors.fill: parent
    radius: Math.max(0, Style.cornerRadius - Style.space(4))
    // Opaque by the time the grid arrives: left even slightly translucent, the
    // lit desktop behind reads straight through a tile and the grid stops
    // being legible. Transparent at the start so the active workspace lines up
    // with the real desktop showing through it.
    color: Util.alpha(Color.background, tile.progress)

    Repeater {
      model: tile.placed

      Item {
        id: thumbnail

        required property var modelData

        readonly property var actual: thumbnail.modelData.actual
        readonly property var target: thumbnail.modelData.target

        // Built at the size it rests at, then moved and scaled into place.
        // Both boxes carry the same window aspect, so a uniform scale is the
        // exact interpolation between them -- and the capture below never has
        // to renegotiate a size mid-gesture.
        width: thumbnail.target.width
        height: thumbnail.target.height
        transformOrigin: Item.TopLeft
        x: Model.lerp(thumbnail.actual.x, thumbnail.target.x, tile.separation)
        y: Model.lerp(thumbnail.actual.y, thumbnail.target.y, tile.separation)
        scale: Model.lerp(thumbnail.actual.width / thumbnail.target.width, 1, tile.separation)

        ScreencopyView {
          anchors.fill: parent
          captureSource: tile.capturing ? thumbnail.modelData.toplevel.wayland : null
          live: true
          paintCursor: false
        }

        MouseArea {
          anchors.fill: parent
          cursorShape: Qt.PointingHandCursor
          onClicked: tile.windowChosen(thumbnail.modelData.toplevel)
        }
      }
    }
  }

  Rectangle {
    anchors.fill: parent
    radius: frame.radius
    color: "transparent"
    border.width: Math.max(1, Style.space(2))
    border.color: tile.active ? Style.selectedBorderColor
      : tile.hovered ? Style.hoverBorderColor
      : "transparent"
    opacity: tile.progress
  }

  Text {
    anchors {
      left: parent.left
      top: parent.top
      margins: Style.space(8)
    }
    text: tile.workspace ? String(tile.workspace.name) : ""
    color: Color.popups.text
    font.family: Style.font.family
    font.pixelSize: Style.font.bodySmall
    opacity: tile.progress
  }
}
