import QtQuick
import Quickshell
import qs.Commons
import qs.Ui

// The bar's toggles as a click-to-open dropdown with labels, instead of
// omarchy.indicators' hover reveal. Hovering a strip of unlabelled glyphs to
// discover what they are is exactly the interaction easy mode exists to remove.
//
// The rows are Omarchy's own indicator components, loaded from the shell tree
// and given a label rather than reimplemented: each one already knows its
// glyph, its on/off state, what pressing it does, and what to call itself.
BarWidget {
  id: root

  moduleName: "pneuma.controls"

  readonly property string omarchyPath: Quickshell.env("OMARCHY_PATH") || "/usr/share/omarchy"
  readonly property var entries: setting("items",
    ["Dnd", "NightLight", "StayAwake", "Dictation", "ScreenRecording", "Reminder"])
  property bool menuOpen: false

  // nf-md-tune: two sliders, the way macOS marks its Control Centre. Written
  // from the codepoint because it is above the BMP and a literal private-use
  // glyph does not survive into QML.
  readonly property string tuneGlyph: String.fromCodePoint(0xF062E)

  function close() {
    root.menuOpen = false
  }

  function indicatorUrl(name) {
    return "file://" + root.omarchyPath + "/shell/plugins/bar/indicators/" + name + ".qml"
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  // An indicator hides itself completely when it is off unless its host says to
  // reveal it. In a dropdown every toggle has to be listed whether it is on or
  // not, so this host always says yes; the indicator still renders itself at
  // 45% while off, which is the row's own on/off cue.
  QtObject {
    id: alwaysReveal

    readonly property bool revealInactiveIndicators: true
  }

  WidgetButton {
    id: button

    anchors.fill: parent
    bar: root.bar
    text: root.tuneGlyph
    active: root.menuOpen
    tooltipText: "Controls"
    onPressed: function (pressedButton) {
      if (pressedButton === Qt.LeftButton) root.menuOpen = !root.menuOpen
    }
  }

  PopupCard {
    id: menu

    anchorItem: root
    owner: root
    bar: root.bar
    open: root.menuOpen
    padding: Style.space(8)
    contentWidth: menu.fittedContentWidth(Style.space(260))
    contentHeight: menu.fittedContentHeight(rowColumn.implicitHeight)

    Column {
      id: rowColumn

      anchors.fill: parent
      spacing: 0

      Repeater {
        model: root.entries

        delegate: Item {
          id: controlRow

          required property var modelData

          readonly property var indicator: indicatorLoader.item
          // Indicators phrase their tooltip as the action pressing them
          // performs ("Silence Notifications"), which is what a menu row wants
          // to say anyway.
          readonly property string label: controlRow.indicator ? String(controlRow.indicator.tooltipText || "") : ""

          width: rowColumn.width
          implicitHeight: Style.space(34)
          visible: controlRow.label !== ""

          Rectangle {
            anchors.fill: parent
            radius: Math.max(2, Style.cornerRadius)
            color: rowMouse.containsMouse ? Style.hoverFillFor(Color.popups.text, Color.accent) : "transparent"
          }

          Loader {
            id: indicatorLoader

            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left
            anchors.leftMargin: Style.space(2)
            // Non-interactive on purpose: the whole row is the click target, so
            // the indicator must not also grab the pointer or raise its own
            // bar tooltip from inside the menu.
            Component.onCompleted: setSource(root.indicatorUrl(String(controlRow.modelData)), {
              bar: root.bar,
              indicatorHost: alwaysReveal,
              interactive: false
            })
          }

          Text {
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left
            anchors.leftMargin: Style.space(34)
            anchors.right: parent.right
            anchors.rightMargin: Style.space(10)
            text: controlRow.label
            color: Color.popups.text
            // Full strength whether the toggle is on or off. The indicator
            // glyph beside it already renders at 45% while off, which carries
            // the state without making half the menu hard to read.
            font.family: Style.font.family
            font.pixelSize: Style.font.bodySmall
            elide: Text.ElideRight
          }

          MouseArea {
            id: rowMouse

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
              root.close()
              if (controlRow.indicator) controlRow.indicator.triggerPress(Qt.LeftButton)
            }
          }
        }
      }
    }
  }
}
