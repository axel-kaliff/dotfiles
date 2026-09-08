import QtQuick
import Quickshell
import qs.Commons
import qs.Ui

// Right-click menu for one dock icon, in the same card and row material as the
// tray's menu. The rows are built here rather than bound, because what belongs
// in the menu depends on the app: its open windows, the actions its .desktop
// file declares (a browser's "New Private Window" and the like), and whether
// there is anything to minimize or quit.
PopupCard {
  id: menu

  // The dock, for the window actions; the row this menu belongs to.
  required property var dock
  property var row: null

  readonly property var entry: menu.row ? DesktopEntries.heuristicLookup(menu.row.appId) : null
  readonly property var windows: menu.row ? menu.row.toplevels : []
  readonly property bool running: menu.windows.length > 0

  readonly property var rows: menu.buildRows()

  function separator() {
    return { separator: true }
  }

  function windowRows(out) {
    // A single window needs no list -- clicking the icon already goes there.
    if (menu.windows.length < 2) return
    for (var i = 0; i < menu.windows.length; i++) {
      var toplevel = menu.windows[i]
      out.push({
        label: String(toplevel.title || menu.row.appId),
        run: function (target) {
          return function () { menu.dock.reveal(target) }
        }(toplevel)
      })
    }
    out.push(menu.separator())
  }

  function actionRows(out) {
    var actions = (menu.entry && menu.entry.actions) ? menu.entry.actions : []
    if (actions.length === 0) return
    for (var i = 0; i < actions.length; i++) {
      var action = actions[i]
      if (!action || !action.name) continue
      out.push({
        label: String(action.name),
        run: function (target) {
          return function () { target.execute() }
        }(action)
      })
    }
    out.push(menu.separator())
  }

  function buildRows() {
    if (!menu.row) return []
    var out = []

    menu.windowRows(out)
    menu.actionRows(out)

    if (!menu.running) {
      out.push({ label: "Open", run: function () { menu.dock.launch(menu.row) } })
    } else if (menu.dock.allMinimized(menu.row)) {
      out.push({ label: "Show", run: function () { menu.dock.showAll(menu.row) } })
    } else {
      out.push({ label: "Minimize", run: function () { menu.dock.minimizeAll(menu.row) } })
    }

    out.push({
      label: "Keep in Dock",
      checked: menu.row.pinned,
      run: function () { menu.dock.togglePin(menu.row) }
    })

    if (menu.running) {
      out.push(menu.separator())
      out.push({ label: "Quit", run: function () { menu.dock.quit(menu.row) } })
    }

    return out
  }

  padding: Style.space(8)
  contentWidth: menu.fittedContentWidth(Style.space(240))
  contentHeight: menu.fittedContentHeight(rowColumn.implicitHeight)

  // The shared popup palette is 0.72 alpha (omarchy/shell.toml), which is tuned
  // for the bar's popups -- and those blur the wallpaper only (`xray`). This one
  // opens over whatever windows happen to be under it, which is far busier, so
  // the card alone leaves the labels hard to read. This backing lifts it to
  // roughly 0.9 without touching the palette every other popup shares.
  // PopupCard paints its own fill and exposes no colour property, so the backing
  // goes inside the content and grows back out over the padding.
  Rectangle {
    anchors.fill: parent
    anchors.margins: -menu.padding
    z: -1
    radius: Style.cornerRadius
    color: Util.alpha(Color.popups.background, 0.65)
  }

  Column {
    id: rowColumn

    anchors.fill: parent
    spacing: 0

    Repeater {
      model: menu.rows

      delegate: Item {
        id: menuRow

        required property var modelData

        readonly property bool isSeparator: menuRow.modelData.separator === true

        width: rowColumn.width
        implicitHeight: menuRow.isSeparator ? Style.space(11) : Style.space(30)

        Rectangle {
          visible: menuRow.isSeparator
          anchors.left: parent.left
          anchors.leftMargin: Style.space(10)
          anchors.right: parent.right
          anchors.rightMargin: Style.space(10)
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
          // Escaped, not literal: a pasted private-use glyph does not
          // survive the round trip and the slot renders blank.
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
          anchors.rightMargin: Style.space(10)
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
          onClicked: {
            var run = menuRow.modelData.run
            menu.open = false
            if (run) run()
          }
        }
      }
    }
  }
}
