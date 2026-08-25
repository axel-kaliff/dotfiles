import QtQuick
import qs.Ui

// A bar entry point for the built-in omarchy.clipboard overlay — the same
// picker SUPER+CTRL+V opens. Deliberately thin: that overlay already owns
// history, search, image and file previews, so this widget only summons it
// rather than growing a second, lesser picker in a popup.
//
// Toggling through `omarchy-shell shell toggle` rather than calling
// bar.shell.toggle() directly mirrors omarchy.menu, the other bar widget that
// summons an overlay.
BarWidget {
  id: root
  moduleName: "pneuma.clipboard"

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "\uf07f"
    tooltipText: "Clipboard Manager"
    onPressed: if (root.bar) root.bar.run("omarchy-shell shell toggle omarchy.clipboard")
  }
}
