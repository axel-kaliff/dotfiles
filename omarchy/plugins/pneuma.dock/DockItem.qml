import QtQuick
import Quickshell
import Quickshell.Widgets
import qs.Commons
import qs.Ui

// One application in the dock: its icon, a dot while it has windows, and the
// name on hover. The icon lifts and grows slightly under the pointer -- the
// dock's own version of the hover pill the bar widgets wear, which reads better
// than a rectangle behind a transparent icon.
Item {
  id: item

  required property var row // { appId, pinned, toplevels }, see DockModel.js
  required property int iconSize
  property var appLibrary: null
  // Every window this app has is parked on the minimized workspace.
  property bool minimized: false
  property bool active: false
  // This icon's context menu is up: the menu is the label now.
  property bool menuOpen: false

  signal chosen
  signal secondary

  readonly property bool running: item.row.toplevels.length > 0
  readonly property var entry: DesktopEntries.heuristicLookup(item.row.appId)
  readonly property string label: {
    if (item.entry && item.appLibrary) return item.appLibrary.entryName(item.entry)
    if (item.entry && item.entry.name) return String(item.entry.name)
    return item.row.appId
  }
  readonly property string iconSource: {
    var name = (item.entry && item.entry.icon) ? item.entry.icon : item.row.appId
    if (item.appLibrary) return item.appLibrary.iconSource(name)
    return Quickshell.iconPath(name, true)
  }
  readonly property bool hovered: hoverTracker.hovered

  // The dot and its gap live below the icon; the label floats above and is not
  // part of the layout, so a long app name never widens the dock.
  readonly property int dotSize: Math.max(3, Math.round(item.iconSize * 0.09))
  readonly property int dotGap: Style.space(4)

  implicitWidth: item.iconSize
  implicitHeight: item.iconSize + item.dotGap + item.dotSize

  HoverHandler { id: hoverTracker }

  MouseArea {
    anchors.fill: parent
    acceptedButtons: Qt.LeftButton | Qt.RightButton
    cursorShape: Qt.PointingHandCursor
    onClicked: function (mouse) {
      if (mouse.button === Qt.RightButton) item.secondary()
      else item.chosen()
    }
  }

  IconImage {
    id: icon

    source: item.iconSource
    implicitSize: item.iconSize
    x: 0
    y: 0
    // A minimized app is still there, just put away: dim it rather than drop it.
    opacity: item.minimized ? 0.55 : 1
    scale: item.hovered ? 1.14 : 1
    transformOrigin: Item.Bottom

    Behavior on scale {
      NumberAnimation { duration: 140; easing.type: Easing.OutBack; easing.overshoot: 1.4 }
    }
    Behavior on opacity {
      NumberAnimation { duration: 140; easing.type: Easing.OutCubic }
    }
  }

  Rectangle {
    width: item.dotSize
    height: item.dotSize
    radius: width / 2
    anchors.horizontalCenter: icon.horizontalCenter
    anchors.top: icon.bottom
    anchors.topMargin: item.dotGap
    color: Color.popups.text
    opacity: item.running ? (item.active ? 0.95 : 0.5) : 0
    visible: opacity > 0

    Behavior on opacity {
      NumberAnimation { duration: 140; easing.type: Easing.OutCubic }
    }
  }

  // The name, in the tooltip material, floating in the panel's headroom above
  // the dock. Not clipped by the item: the panel is taller than the dock bar
  // precisely so this has somewhere to go.
  BorderSurface {
    id: tip

    readonly property int pad: Style.space(6)

    parent: item
    anchors.horizontalCenter: item.horizontalCenter
    anchors.bottom: item.top
    anchors.bottomMargin: Style.space(10)
    width: tipText.implicitWidth + pad * 2 + borderLeft + borderRight
    height: tipText.implicitHeight + pad + borderTop + borderBottom
    radius: Math.max(0, Style.cornerRadius - Style.space(6))
    color: Color.tooltip.background
    borderSpec: Border.surfaceSpec("tooltip", "border", Color.tooltip.border, 1)
    opacity: (item.hovered && !item.menuOpen) ? 1 : 0
    visible: opacity > 0

    Behavior on opacity {
      NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
    }

    Text {
      id: tipText

      anchors.centerIn: parent
      text: item.label
      color: Color.tooltip.text
      font.family: Style.font.family
      font.pixelSize: Style.font.bodySmall
      maximumLineCount: 1
    }
  }
}
