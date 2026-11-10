import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Widgets
import qs.Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "omarchy.workspaces"

  // Every monitor has workspaces 1-10 of its own, which Hyprland numbers in a
  // block of ten per monitor: 1-10, 11-20, and so on (see
  // default/hypr/monitor-workspaces.lua). Each bar shows its own monitor's block,
  // numbered 1-10, and the one that monitor shows, whichever monitor has focus.
  readonly property int slots: 10

  readonly property var monitor: {
    var window = root.QsWindow.window
    var screen = window ? window.screen : null
    return screen ? Hyprland.monitorFor(screen) : Hyprland.focusedMonitor
  }
  readonly property string monitorName: root.monitor ? root.monitor.name : ""

  // Connector -> block, from the file Hyprland keeps them in.
  property var blocks: ({})

  function readBlocks(text) {
    var next = {}
    var lines = String(text || "").split("\n")
    for (var i = 0; i < lines.length; i++) {
      var fields = lines[i].split("\t")
      if (fields.length >= 3 && fields[1] !== "") next[fields[1]] = parseInt(fields[0], 10)
    }
    root.blocks = next
  }

  FileView {
    path: (Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state") + "/omarchy/monitor-workspaces"
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: root.readBlocks(text())
    onLoadFailed: root.readBlocks("")
  }

  function blockOf(id) {
    return Math.floor((id - 1) / root.slots)
  }

  function slotOf(id) {
    return (id - 1) % root.slots + 1
  }

  function activeWorkspaceId() {
    return root.monitor && root.monitor.activeWorkspace ? root.monitor.activeWorkspace.id : -1
  }

  // Until Hyprland has written the file, the workspace a monitor shows is in
  // its own block.
  readonly property int block: {
    var block = root.blocks[root.monitorName]
    if (block !== undefined) return block
    var active = root.activeWorkspaceId()
    return active > 0 ? root.blockOf(active) : 0
  }

  function workspaceById(id) {
    var values = Hyprland.workspaces.values
    for (var i = 0; i < values.length; i++) {
      if (values[i].id === id) return values[i]
    }

    return null
  }

  // All ten of the monitor's own workspaces are shown. After them come
  // workspaces that are only visiting: those of a monitor that is unplugged,
  // which had no room to join this one's.
  function workspaceIds() {
    var base = root.block * root.slots
    var ids = []
    for (var slot = 1; slot <= root.slots; slot++) ids.push(base + slot)
    var guests = []
    var values = Hyprland.workspaces.values

    for (var i = 0; i < values.length; i++) {
      var id = values[i].id
      if (id <= 0 || root.blockOf(id) === root.block) continue
      if (values[i].monitor && values[i].monitor.name === root.monitorName) {
        guests.push(id)
      }
    }

    guests.sort(function(left, right) { return left - right })
    return ids.concat(guests)
  }

  // One icon per distinct app on the workspace, in window order, capped so a
  // busy workspace stays a pill rather than a dock. The app id comes from the
  // toplevel protocol (live) with the IPC class as fallback, and is resolved
  // through the desktop entries the way the launcher does.
  readonly property int maxIcons: 4

  function toplevelAppId(toplevel) {
    var wayland = toplevel.wayland
    if (wayland && wayland.appId) return wayland.appId
    var ipc = toplevel.lastIpcObject
    return ipc && ipc.class ? String(ipc.class) : ""
  }

  function iconForAppId(appId) {
    var entry = DesktopEntries.heuristicLookup(appId)
    return entry && entry.icon ? Quickshell.iconPath(entry.icon, true) : ""
  }

  function iconsFor(workspace) {
    if (!workspace) return []
    var toplevels = workspace.toplevels.values
    var seen = {}
    var icons = []
    for (var i = 0; i < toplevels.length && icons.length < root.maxIcons; i++) {
      var appId = toplevelAppId(toplevels[i])
      if (!appId || seen[appId]) continue
      seen[appId] = true
      var icon = iconForAppId(appId)
      if (icon) icons.push(icon)
    }
    return icons
  }

  function dispatch(expression) {
    if (root.bar) root.bar.run("hyprctl dispatch " + Util.shellQuote(expression))
  }

  function focusWorkspace(id) {
    if (root.blockOf(id) === root.block) {
      root.dispatch("o.workspaces.focus(" + root.slotOf(id) + ", \"" + root.monitorName + "\")")
    } else {
      root.dispatch("hl.dsp.focus({ workspace = \"" + id + "\" })")
    }
  }

  Connections {
    target: Hyprland
    function onRawEvent(event) {
      var name = event ? String(event.name) : ""
      // Quickshell credits every workspace switch to the focused monitor, as
      // the event doesn't say which one switched, and misses the workspace a
      // monitor falls back to when its own is moved away. Moving workspaces
      // between monitors switches the others, so ask Hyprland for the truth.
      // A workspace that changes number is only learned by asking too. Every
      // bar shares what Hyprland answers, so one asks after a plain switch.
      var switched = name === "workspacev2" && root.monitor !== null && root.monitor.focused
      if (switched || name === "moveworkspacev2" || name === "changeworkspaceid") {
        Hyprland.refreshMonitors()
        Hyprland.refreshWorkspaces()
      }
    }
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
        readonly property bool shown: root.monitor !== null && root.monitor.activeWorkspace !== null && root.monitor.activeWorkspace.id === modelData
        readonly property int slot: root.slotOf(modelData)
        readonly property bool firstGuest: root.blockOf(modelData) !== root.block && index > 0 && root.blockOf(root.workspaceIds()[index - 1]) === root.block
        required property int index

        // A gap sets visiting workspaces apart from the monitor's own.
        Layout.leftMargin: firstGuest && !root.vertical ? Style.space(6) : 0
        Layout.topMargin: firstGuest && root.vertical ? Style.space(6) : 0

        // The digit keeps its own slot; app icons extend the pill to the
        // right of it on a horizontal bar. A vertical bar has no room and
        // stays digits only.
        readonly property var appIcons: root.vertical ? [] : root.iconsFor(workspace)
        readonly property int digitSlot: root.vertical ? root.barSize : Style.space(22)
        readonly property int iconSize: Style.space(14)
        readonly property int iconGap: Style.space(4)
        readonly property int iconsWidth: appIcons.length === 0 ? 0
          : appIcons.length * iconSize + (appIcons.length - 1) * iconGap + Style.space(9)

        bar: root.bar
        text: slot === root.slots ? "0" : String(slot)
        opacity: occupied || shown ? 1 : 0.5
        horizontalMargin: 6
        verticalPadding: 6
        fixedWidth: digitSlot + iconsWidth
        fixedHeight: root.barSize
        onPressed: function() { root.focusWorkspace(modelData) }

        // A digit has to sit dead centre in its pill, and two things stop the
        // stock label from managing it: it centres the glyph's advance box
        // rather than the ink inside it, and native rendering then snaps the
        // result to a whole pixel. Both leave the number reading left of the
        // circle. So the glyph is placed on the pixel that best centres its
        // ink, and the pill — which antialiases freely — is centred on where
        // that ink actually lands, absorbing the leftover fraction.
        labelVisible: false

        readonly property real inkCenter: digitMetrics.tightBoundingRect.x
          + digitMetrics.tightBoundingRect.width / 2
        readonly property real glyphX: Math.round(digitSlot / 2 - inkCenter)
        readonly property real paintedCenter: glyphX + inkCenter

        TextMetrics {
          id: digitMetrics
          font.family: cell.fontFamily
          font.pixelSize: Math.max(1, Math.round(cell.fontSize))
          text: cell.text
        }

        Text {
          x: cell.glyphX
          anchors.verticalCenter: parent.verticalCenter
          text: cell.text
          color: cell.foreground
          font: digitMetrics.font
          renderType: Text.NativeRendering
        }

        Row {
          x: cell.digitSlot - Style.space(2)
          anchors.verticalCenter: parent.verticalCenter
          spacing: cell.iconGap

          Repeater {
            model: cell.appIcons

            IconImage {
              required property string modelData
              source: modelData
              implicitSize: cell.iconSize
              opacity: cell.shown ? 1 : 0.85
            }
          }
        }

        // The focused workspace sits in a glass pill, the tab-bar idiom, and
        // keeps its number instead of turning into a filled-square glyph;
        // hovering another one lifts it slightly. Same [controls] tokens as
        // the bar's open-panel capsule.
        BorderSurface {
          readonly property int inset: Style.space(3)

          z: -1
          width: parent.width - (root.vertical ? inset : Style.space(1)) * 2
          height: parent.height - (root.vertical ? Style.space(1) : inset) * 2
          anchors.verticalCenter: parent.verticalCenter
          anchors.horizontalCenter: parent.horizontalCenter
          anchors.horizontalCenterOffset: cell.paintedCenter - cell.digitSlot / 2
          radius: Math.min(Style.cornerRadius, Math.min(width, height) / 2)
          color: cell.shown ? Style.selectedFillFor(cell.foreground, Color.accent)
            : cell.tooltipHovered ? Style.hoverFillFor(cell.foreground, Color.accent)
            : "transparent"
          borderSpec: cell.shown ? Border.controlSpec("selected", cell.foreground, Color.accent) : Border.none()

          Behavior on color {
            ColorAnimation { duration: 140; easing.type: Easing.OutCubic }
          }
        }
      }
    }
  }
}
