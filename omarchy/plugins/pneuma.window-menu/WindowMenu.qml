import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.Commons
import qs.Ui
import "WindowMenuModel.js" as Model

// The menu SUPER + right-click raises on a window. The compositor half is in
// hypr/bindings.lua: it finds the window under the pointer, reads the state the
// rows need, and hands both over as JSON -- so this never has to ask Hyprland
// what it is looking at, and the labels are right the moment the menu appears.
//
// Every row acts by address, in Lua, because that is what Hyprland's dispatch
// takes on this config. None of it is easy-mode-only: a floating window is worth
// pinning whichever mode you are in.
Item {
  id: root

  readonly property string minimizedWorkspace: "special:minimized"

  property bool opened: false
  property string address: ""
  property int cursorX: 0
  property int cursorY: 0
  property bool floating: false
  property bool pinned: false
  property int fullscreen: 0

  readonly property var rows: Model.rows(root.floating, root.pinned, root.fullscreen)

  function close() {
    root.opened = false
  }

  function show(payload) {
    var data
    try {
      data = JSON.parse(payload)
    } catch (error) {
      return "bad payload"
    }
    if (!data || !data.address) return "no window"

    root.address = String(data.address)
    root.cursorX = Number(data.x) || 0
    root.cursorY = Number(data.y) || 0
    root.floating = data.floating === true
    root.pinned = data.pinned === true
    root.fullscreen = Number(data.fullscreen) || 0
    root.opened = true
    return "ok"
  }

  // Hyprland reports addresses with the 0x that its own selector expects, and
  // the payload is built from that side, so it is passed straight through.
  function selector() {
    return 'hl.get_window("address:' + root.address + '")'
  }

  function dispatch(expression) {
    Hyprland.dispatch(expression)
  }

  function run(action) {
    root.close()
    if (root.address === "") return

    var target = root.selector()
    if (action === "float") {
      root.dispatch("hl.dsp.window.float({ window = " + target + " })")
    } else if (action === "sticky") {
      // Pinning is only meaningful for a floating window, so a tiled one is
      // floated first -- which is what "always on top, on every workspace"
      // means for a window currently owned by the layout.
      if (!root.floating) root.dispatch("hl.dsp.window.float({ window = " + target + " })")
      root.dispatch("hl.dsp.window.pin({ window = " + target + " })")
    } else if (action === "maximize") {
      root.dispatch("hl.dsp.window.fullscreen({ window = " + target + ", mode = 1 })")
    } else if (action === "fullscreen") {
      root.dispatch("hl.dsp.window.fullscreen({ window = " + target + ", mode = 0 })")
    } else if (action === "center") {
      root.dispatch("hl.dsp.window.center({ window = " + target + " })")
    } else if (action === "minimize") {
      root.dispatch("hl.dsp.window.move({ workspace = \"" + root.minimizedWorkspace
        + "\", follow = false, window = " + target + " })")
    } else if (action === "close") {
      root.dispatch("hl.dsp.window.close({ window = " + target + " })")
    }
  }

  IpcHandler {
    target: "pneuma.window-menu"

    function open(payload: string): string {
      return root.show(payload)
    }

    function dismiss(): string {
      root.close()
      return "ok"
    }

    function state(): string {
      return JSON.stringify({
        opened: root.opened,
        address: root.address,
        floating: root.floating,
        pinned: root.pinned,
        fullscreen: root.fullscreen,
        rows: root.rows.map(function (row) { return row.separator ? "---" : row.label })
      })
    }
  }

  Variants {
    model: Quickshell.screens

    PanelWindow {
      id: panel

      required property var modelData

      // Cursor position arrives in compositor coordinates; a layer surface is
      // placed in its own screen's, so the offset comes off here.
      readonly property int localX: root.cursorX - panel.modelData.x
      readonly property int localY: root.cursorY - panel.modelData.y
      readonly property bool onThisScreen: panel.localX >= 0 && panel.localY >= 0
        && panel.localX < panel.modelData.width && panel.localY < panel.modelData.height

      screen: panel.modelData
      visible: root.opened && panel.onThisScreen
      color: "transparent"
      WlrLayershell.namespace: "pneuma-window-menu"
      WlrLayershell.layer: WlrLayer.Overlay
      // Taken only while the menu is up, so Escape lands here rather than in the
      // window the menu is about.
      WlrLayershell.keyboardFocus: panel.visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
      exclusionMode: ExclusionMode.Ignore

      anchors {
        top: true
        bottom: true
        left: true
        right: true
      }

      // Anywhere off the card dismisses, the way a context menu should.
      MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: root.close()
      }

      Item {
        anchors.fill: parent
        focus: true

        Keys.onPressed: function (event) {
          if (event.key !== Qt.Key_Escape) return
          root.close()
          event.accepted = true
        }
      }

      RectangularShadow {
        anchors.fill: card
        radius: card.radius
        blur: Style.space(28)
        offset.y: Style.space(6)
        color: Qt.rgba(0, 0, 0, 0.3)
      }

      BorderSurface {
        id: card

        readonly property int pad: Style.space(8)

        // Opens down and right of the pointer, and flips back over it rather
        // than hanging off the screen edge.
        x: Math.max(Style.space(4),
          Math.min(panel.localX, panel.width - card.width - Style.space(4)))
        y: Math.max(Style.space(4),
          Math.min(panel.localY, panel.height - card.height - Style.space(4)))
        width: Style.space(220)
        height: column.implicitHeight + card.pad * 2 + borderTop + borderBottom
        radius: Style.cornerRadius
        color: Color.popups.background
        borderSpec: Border.surfaceSpec("popups", "border", Color.popups.border, Math.max(1, Style.space(2)))

        // Same reasoning as the dock's menu: the popup palette is 0.72 alpha,
        // tuned for a frosted backdrop, and this one lands over whatever window
        // was right-clicked. The layer rule blurs it; this makes it opaque
        // enough to read over a busy one.
        Rectangle {
          anchors.fill: parent
          anchors.margins: 1
          radius: card.radius
          color: Util.alpha(Color.popups.background, 0.65)
        }

        Column {
          id: column

          x: card.borderLeft + card.pad
          y: card.borderTop + card.pad
          width: card.width - card.pad * 2 - card.borderLeft - card.borderRight
          spacing: 0

          Repeater {
            model: root.rows

            delegate: Item {
              id: menuRow

              required property var modelData

              readonly property bool isSeparator: menuRow.modelData.separator === true

              width: column.width
              implicitHeight: menuRow.isSeparator ? Style.space(11) : Style.space(30)

              Rectangle {
                visible: menuRow.isSeparator
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                height: 1
                color: Color.popups.border
                opacity: 0.45
              }

              Rectangle {
                visible: !menuRow.isSeparator
                anchors.fill: parent
                radius: Math.max(2, Style.cornerRadius)
                color: rowMouse.containsMouse ? Style.hoverFillFor(Color.popups.text, Color.accent) : "transparent"
              }

              Text {
                visible: !menuRow.isSeparator
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: parent.left
                width: Style.space(22)
                horizontalAlignment: Text.AlignHCenter
                // Escaped rather than pasted: a literal private-use glyph does
                // not survive into QML.
                text: menuRow.modelData.checked === true ? "\uf00c" : ""
                color: Color.popups.text
                font.family: Style.font.family
                font.pixelSize: Style.font.bodySmall
              }

              Text {
                visible: !menuRow.isSeparator
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: parent.left
                anchors.leftMargin: Style.space(28)
                anchors.right: parent.right
                text: String(menuRow.modelData.label || "")
                color: Color.popups.text
                font.family: Style.font.family
                font.pixelSize: Style.font.bodySmall
                elide: Text.ElideRight
              }

              MouseArea {
                id: rowMouse

                anchors.fill: parent
                enabled: !menuRow.isSeparator
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.run(String(menuRow.modelData.action || ""))
              }
            }
          }
        }
      }
    }
  }
}
