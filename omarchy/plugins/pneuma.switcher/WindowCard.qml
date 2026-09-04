import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import qs.Commons
import qs.Ui

// One window in the switcher: a live thumbnail over the app icon and title.
// The highlighted card wears the same glass pill as the bar's focused
// workspace. Capture only runs while the overlay is up, so the cost of a
// live view of every window is paid for the second it is being looked at.
BorderSurface {
  id: card

  required property var toplevel
  property bool selected: false
  property bool capturing: false
  property int thumbWidth: Style.space(220)
  property int thumbHeight: Style.space(138)

  signal chosen()

  readonly property int pad: Style.space(8)
  readonly property int labelHeight: Style.space(18)
  readonly property string appId: toplevel ? String(toplevel.appId) : ""
  readonly property string title: toplevel ? String(toplevel.title) : ""
  readonly property string iconSource: {
    var entry = DesktopEntries.heuristicLookup(appId)
    var name = entry && entry.icon ? entry.icon : ""
    return name ? Quickshell.iconPath(name, true) : ""
  }
  readonly property bool hovered: hoverTracker.hovered

  width: thumbWidth + pad * 2
  height: thumbHeight + labelHeight + pad * 3
  radius: Math.max(0, Style.cornerRadius - Style.space(4))
  color: selected ? Style.selectedFillFor(Color.popups.text, Color.accent)
    : hovered ? Style.hoverFillFor(Color.popups.text, Color.accent)
    : "transparent"
  borderSpec: selected ? Border.controlSpec("selected", Color.popups.text, Color.accent) : Border.none()

  Behavior on color {
    ColorAnimation { duration: 120; easing.type: Easing.OutCubic }
  }

  HoverHandler { id: hoverTracker }

  MouseArea {
    anchors.fill: parent
    cursorShape: Qt.PointingHandCursor
    onClicked: card.chosen()
  }

  ClippingRectangle {
    id: frame
    x: card.pad
    y: card.pad
    width: card.thumbWidth
    height: card.thumbHeight
    radius: Math.max(0, card.radius - Style.space(2))
    color: Util.alpha(Color.popups.text, 0.06)

    ScreencopyView {
      anchors.centerIn: parent
      captureSource: card.capturing ? card.toplevel : null
      live: true
      paintCursor: false
      constraintSize: Qt.size(frame.width, frame.height)
    }
  }

  Row {
    x: card.pad
    y: card.pad * 2 + card.thumbHeight
    width: card.thumbWidth
    height: card.labelHeight
    spacing: Style.space(6)

    IconImage {
      visible: card.iconSource !== ""
      source: card.iconSource
      implicitSize: Style.space(16)
      anchors.verticalCenter: parent.verticalCenter
    }

    Text {
      width: parent.width - (card.iconSource !== "" ? Style.space(22) : 0)
      anchors.verticalCenter: parent.verticalCenter
      text: card.title
      color: Color.popups.text
      font.family: Style.font.family
      font.pixelSize: Style.font.bodySmall
      elide: Text.ElideRight
      maximumLineCount: 1
    }
  }
}
