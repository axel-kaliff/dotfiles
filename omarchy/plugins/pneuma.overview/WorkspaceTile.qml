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
Item {
  id: tile

  required property var workspace
  required property var monitor
  required property bool capturing
  required property bool active
  required property real progress

  signal windowChosen(var toplevel)
  signal chosen()

  readonly property bool hovered: hoverTracker.hovered
  readonly property var frameBox: ({ x: 0, y: 0, width: frame.width, height: frame.height })

  // Each window with both of its boxes worked out in the same pass: where it
  // really is, and the slot it spreads into. Deriving them together is what
  // makes it impossible to index one apart from the other.
  //
  // A window Hyprland has not described yet is simply not in the list --
  // `lastIpcObject` is an empty, and so still truthy, map until it has been,
  // which is why the geometry itself is what gets checked.
  readonly property var placed: {
    if (!tile.monitor) return []
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

  // Windows come apart ahead of the swipe rather than in step with it: eased
  // this way they are already legible around the halfway mark, where a linear
  // separation still has them piled up at exactly the moment you are looking.
  // Only the windows lead -- the tile itself keeps tracking the fingers.
  readonly property real separation: 1 - Math.pow(1 - tile.progress, 3)

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
    // Both grow with the swipe: a square, transparent tile at the start lines
    // the active workspace up with the real desktop showing through it, and a
    // rounded, opaque card once the grid has arrived. Opaque matters -- left
    // even slightly translucent, the lit desktop behind reads straight
    // through a tile and the grid stops being legible.
    radius: Math.max(0, Style.cornerRadius - Style.space(4)) * tile.progress
    color: Util.alpha(Color.background, tile.progress)

    Repeater {
      model: tile.placed

      Item {
        id: thumbnail

        required property var modelData

        readonly property var box: Model.lerpRect(thumbnail.modelData.actual,
          thumbnail.modelData.target, tile.separation)

        x: thumbnail.box.x
        y: thumbnail.box.y
        width: thumbnail.box.width
        height: thumbnail.box.height

        // Constrained to the size it is drawn at, not the window's real size:
        // a grid of live full-resolution captures is not worth paying for when
        // every one of them lands in a box this small. The box already carries
        // the window's true aspect, so fitting inside it fills it.
        ScreencopyView {
          anchors.centerIn: parent
          captureSource: tile.capturing ? thumbnail.modelData.toplevel.wayland : null
          live: true
          paintCursor: false
          constraintSize: Qt.size(Math.max(1, thumbnail.width), Math.max(1, thumbnail.height))
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
