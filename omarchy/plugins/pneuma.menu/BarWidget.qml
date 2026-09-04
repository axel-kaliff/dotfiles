import QtQuick
import qs.Ui

// The bar's menu button: the stock omarchy.menu widget's two clicks (left the
// command menu, right a terminal) behind a Nerd Font glyph instead of the
// Omarchy logo from the "omarchy" icon font.
BarWidget {
  id: root
  moduleName: "pneuma.menu"

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "󰖝"
    horizontalMargin: 7.5
    onPressed: function(button) {
      if (!root.bar) return
      if (button === Qt.RightButton) root.bar.run("xdg-terminal-exec")
      else root.bar.run("omarchy-shell shell toggle omarchy.menu '{\"menu\":\"root\"}'")
    }
  }
}
