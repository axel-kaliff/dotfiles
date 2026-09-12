import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import qs.Commons
import qs.Ui
import "OverviewModel.js" as Model

// One workspace in the overview: every window on it as a live thumbnail, each
// at the place it really occupies, so the tile is a true miniature of that
// workspace rather than a list of what happens to be on it.
Item {
  id: tile

  required property var workspace
  required property var monitor
  required property bool capturing
  required property bool active
  required property real progress

  signal windowChosen(var toplevel)
  signal chosen()

  readonly property var windows: tile.workspace && tile.workspace.toplevels
    ? tile.workspace.toplevels.values
    : []
  readonly property bool hovered: hoverTracker.hovered

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
    // rounded, filled card once the grid has arrived.
    radius: Math.max(0, Style.cornerRadius - Style.space(4)) * tile.progress
    color: Util.alpha(Color.background, tile.progress * 0.85)

    Repeater {
      model: tile.windows

      Item {
        id: thumbnail

        required property var modelData

        readonly property var geometry: thumbnail.modelData.lastIpcObject && tile.monitor
          ? Model.windowRect(thumbnail.modelData.lastIpcObject.at, thumbnail.modelData.lastIpcObject.size,
              tile.monitor, { x: 0, y: 0, width: frame.width, height: frame.height })
          : null

        visible: thumbnail.geometry !== null
        x: thumbnail.geometry ? thumbnail.geometry.x : 0
        y: thumbnail.geometry ? thumbnail.geometry.y : 0
        width: thumbnail.geometry ? thumbnail.geometry.width : 0
        height: thumbnail.geometry ? thumbnail.geometry.height : 0

        // Constrained to the thumbnail it is drawn at, not the window's real
        // size: a grid of six live full-resolution captures is not worth
        // paying for when every one of them lands in a box this small. The
        // box already carries the window's true aspect, so fitting inside it
        // fills it.
        ScreencopyView {
          anchors.centerIn: parent
          captureSource: tile.capturing ? thumbnail.modelData.wayland : null
          live: true
          paintCursor: false
          constraintSize: Qt.size(Math.max(1, thumbnail.width), Math.max(1, thumbnail.height))
        }

        MouseArea {
          anchors.fill: parent
          cursorShape: Qt.PointingHandCursor
          onClicked: tile.windowChosen(thumbnail.modelData)
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
