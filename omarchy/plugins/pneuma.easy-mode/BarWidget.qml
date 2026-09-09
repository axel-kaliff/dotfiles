import QtQuick
import Quickshell
import Quickshell.Io
import qs.Ui

// Bar button for easy mode: the floating, mouse-driven desktop. Lit while it is
// on. This is the route that needs neither a keyboard nor knowing where the
// launcher hides its Style submenu, which is rather the point of easy mode.
BarWidget {
  id: root

  moduleName: "pneuma.easy-mode"

  readonly property string home: Quickshell.env("HOME")
  readonly property string flagPath: root.home + "/.local/state/omarchy/toggles/hypr/easy-mode.lua"
  property bool easyMode: false

  // Written out of the codepoint rather than pasted: a literal private-use
  // glyph does not survive into QML, and "d" would parse as U+F037 then
  // "d" -- this one is above the BMP.
  readonly property string mouseGlyph: String.fromCodePoint(0xF037D)

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  WidgetButton {
    id: button

    anchors.fill: parent
    bar: root.bar
    text: root.mouseGlyph
    // Dimmed when off, full strength when on, rather than the bar's `active`
    // colour: that one is the urgent red, which is right for a pomodoro that
    // is running out and wrong for a mode that may be left on for days.
    dimmed: !root.easyMode
    tooltipText: root.easyMode ? "Easy mode on" : "Easy mode off"
    onPressed: function (pressedButton) {
      if (pressedButton !== Qt.LeftButton || !root.bar) return
      root.bar.run(root.home + "/.config/hypr/bin/easy-mode toggle")
    }
  }

  // Presence of the flag file = easy mode on. The directory is watched rather
  // than the file: FileView cannot observe one that does not exist yet, and the
  // flag is created and removed by `easy-mode`.
  Process {
    id: flagProbe

    running: true
    command: ["bash", "-c", "[[ -f " + root.flagPath + " ]] && echo yes || echo no"]
    stdout: SplitParser {
      onRead: function (line) {
        root.easyMode = String(line).trim() === "yes"
      }
    }
  }

  FileView {
    path: root.home + "/.local/state/omarchy/toggles/hypr"
    watchChanges: true
    printErrors: false
    onFileChanged: flagProbe.running = true
  }
}
