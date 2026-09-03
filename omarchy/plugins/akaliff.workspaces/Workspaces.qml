import QtQuick
import QtQuick.Layouts
import Quickshell.Hyprland
import qs.Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "omarchy.workspaces"

  function workspaceById(id) {
    var values = Hyprland.workspaces.values
    for (var i = 0; i < values.length; i++) {
      if (values[i].id === id) return values[i]
    }

    return null
  }

  function workspaceIds() {
    var ids = [1, 2, 3, 4, 5]
    var values = Hyprland.workspaces.values

    for (var i = 0; i < values.length; i++) {
      var id = values[i].id
      if (id > 0 && id <= 10 && ids.indexOf(id) === -1) ids.push(id)
    }

    ids.sort(function(left, right) { return left - right })
    return ids
  }

  function focusWorkspace(id) {
    if (!root.bar) return
    root.bar.run("hyprctl dispatch " + Util.shellQuote("hl.dsp.focus({ workspace = \"" + id + "\" })"))
  }

  readonly property real trailingGap: root.vertical ? 0 : Style.spaceReal(1.5)

  implicitWidth: grid.implicitWidth + trailingGap
  implicitHeight: grid.implicitHeight

  GridLayout {
    id: grid
    anchors.fill: parent
    anchors.rightMargin: root.trailingGap
    columns: root.vertical ? 1 : root.workspaceIds().length
    columnSpacing: root.vertical ? 0 : Style.space(1)
    rowSpacing: root.vertical ? Style.space(2) : 0

    Repeater {
      model: root.workspaceIds()

      WidgetButton {
        id: cell
        required property int modelData

        readonly property var workspace: root.workspaceById(modelData)
        readonly property bool occupied: workspace !== null && workspace.toplevels.values.length > 0
        readonly property bool focused: Hyprland.focusedWorkspace !== null && Hyprland.focusedWorkspace.id === modelData

        bar: root.bar
        text: modelData === 10 ? "0" : String(modelData)
        opacity: occupied || focused ? 1 : 0.5
        horizontalMargin: 6
        verticalPadding: 6
        fixedWidth: root.vertical ? root.barSize : Style.space(22)
        fixedHeight: root.barSize
        onPressed: function() { root.focusWorkspace(modelData) }

        // The focused workspace sits in a glass pill, the tab-bar idiom, and
        // keeps its number instead of turning into a filled-square glyph;
        // hovering another one lifts it slightly. Same [controls] tokens as
        // the bar's open-panel capsule.
        BorderSurface {
          readonly property int inset: Style.space(3)

          z: -1
          anchors.fill: parent
          anchors.topMargin: root.vertical ? Style.space(1) : inset
          anchors.bottomMargin: root.vertical ? Style.space(1) : inset
          anchors.leftMargin: root.vertical ? inset : Style.space(1)
          anchors.rightMargin: root.vertical ? inset : Style.space(1)
          radius: Math.min(Style.cornerRadius, Math.min(width, height) / 2)
          color: cell.focused ? Style.selectedFillFor(cell.foreground, Color.accent)
            : cell.tooltipHovered ? Style.hoverFillFor(cell.foreground, Color.accent)
            : "transparent"
          borderSpec: cell.focused ? Border.controlSpec("selected", cell.foreground, Color.accent) : Border.none()

          Behavior on color {
            ColorAnimation { duration: 140; easing.type: Easing.OutCubic }
          }
        }
      }
    }
  }
}
