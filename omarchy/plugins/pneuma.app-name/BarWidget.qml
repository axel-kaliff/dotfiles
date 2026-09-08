import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Commons
import qs.Ui

// The focused application's name, in bold, at the left of the bar: the macOS
// menu bar's signature, and the reason this exists alongside
// omarchy.active-window. That widget shows the window *title*, which on macOS
// is on the window itself -- the bar names the application.
BarWidget {
  id: root

  moduleName: "pneuma.app-name"

  readonly property var toplevel: ToplevelManager.activeToplevel
  readonly property string appName: {
    var appId = root.toplevel ? String(root.toplevel.appId || "") : ""
    if (appId === "") return ""
    var entry = DesktopEntries.heuristicLookup(appId)
    // The app id is the fallback name: better a terse "com.slack.slack" than an
    // empty slot where the focused app should be.
    return (entry && entry.name) ? String(entry.name) : appId
  }

  // A vertical bar has no room for a name, and the macOS bar it imitates is
  // horizontal by definition.
  visible: root.appName !== "" && !root.vertical
  implicitWidth: root.visible ? label.implicitWidth + Style.spacing.controlPaddingX * 2 : 0
  implicitHeight: root.barSize

  Text {
    id: label

    anchors.centerIn: parent
    text: root.appName
    color: root.bar ? root.bar.barForeground : Color.foreground
    font.family: root.bar ? root.bar.fontFamily : Style.font.family
    font.pixelSize: Style.font.body
    font.bold: true
    elide: Text.ElideRight
    maximumLineCount: 1
  }
}
