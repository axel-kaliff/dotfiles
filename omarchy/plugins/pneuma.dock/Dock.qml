import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.Commons
import qs.Ui
import "DockModel.js" as Model

// A macOS-style dock, on screen only while easy mode is on. It is the mouse's
// route to the things the keyboard normally does here: launching an app,
// switching between windows, and putting one away.
//
// Minimizing is the reason the dock has to talk to Hyprland directly rather
// than through the foreign-toplevel protocol. Hyprland drops
// xdg_toplevel.set_minimized (hyprwm/Hyprland#3984), so a window is "minimized"
// by parking it on a special workspace, which only its Hyprland-side handle can
// address. Hyprland's dispatch takes Lua on this config, hence the expressions.
Item {
  id: root

  // Injected by the shell host. Carries the app library: the icon fallback
  // chain and desktop-entry launching with the launch OSD.
  property var shell: null
  readonly property var appLibrary: root.shell ? root.shell.appLibrary : null
  readonly property string home: Quickshell.env("HOME")

  readonly property string minimizedWorkspace: "special:minimized"
  readonly property string easyModeFlag: root.home + "/.local/state/omarchy/toggles/hypr/easy-mode.lua"

  property bool easyMode: false

  readonly property var pinnedIds: pinFile.adapter ? pinFile.adapter.apps : []
  readonly property var toplevels: ToplevelManager.toplevels ? ToplevelManager.toplevels.values : []
  readonly property var rows: Model.rows(root.pinnedIds, root.toplevels)

  readonly property int iconSize: Style.space(44)
  readonly property int barPad: Style.space(10)
  readonly property int edgeGap: Style.space(8)
  // Empty space kept above the bar so a hover label has somewhere to go. It is
  // masked out of the input region, so it costs nothing but pixels.
  readonly property int headroom: Style.space(44)

  // Hyprland's handle for a wlr toplevel. `wayland` is the cross-link between
  // the two views of the same window.
  function hyprToplevel(toplevel) {
    var list = Hyprland.toplevels ? Hyprland.toplevels.values : []
    for (var i = 0; i < list.length; i++) {
      if (list[i].wayland === toplevel) return list[i]
    }
    return null
  }

  function isMinimized(toplevel) {
    var handle = root.hyprToplevel(toplevel)
    return !!(handle && handle.workspace && String(handle.workspace.name) === root.minimizedWorkspace)
  }

  function allMinimized(row) {
    if (row.toplevels.length === 0) return false
    for (var i = 0; i < row.toplevels.length; i++) {
      if (!root.isMinimized(row.toplevels[i])) return false
    }
    return true
  }

  function isActiveRow(row) {
    var active = ToplevelManager.activeToplevel
    for (var i = 0; i < row.toplevels.length; i++) {
      if (row.toplevels[i] === active) return true
    }
    return false
  }

  // Quickshell reports the address without the 0x that Hyprland's own window
  // selector expects, so it goes back on here.
  function windowSelector(handle) {
    return 'hl.get_window("address:0x' + handle.address + '")'
  }

  function moveToWorkspace(toplevel, workspaceExpression) {
    var handle = root.hyprToplevel(toplevel)
    if (!handle) return
    Hyprland.dispatch("hl.dsp.window.move({ workspace = " + workspaceExpression
      + ", follow = false, window = " + root.windowSelector(handle) + " })")
  }

  function focusWindow(toplevel) {
    var handle = root.hyprToplevel(toplevel)
    if (!handle) return
    Hyprland.dispatch("hl.dsp.focus({ window = " + root.windowSelector(handle) + " })")
  }

  function minimize(toplevel) {
    root.moveToWorkspace(toplevel, '"' + root.minimizedWorkspace + '"')
  }

  // Restores onto whichever workspace is being looked at, so a window comes
  // back to the user rather than to wherever it was put away from. The target
  // is resolved by Hyprland, in the same dispatch, to keep the two in step.
  function restore(toplevel) {
    root.moveToWorkspace(toplevel, "tostring(hl.get_active_workspace().id)")
    root.focusWindow(toplevel)
  }

  function launch(row) {
    var entry = DesktopEntries.heuristicLookup(row.appId)
    if (!entry) return
    if (root.appLibrary) root.appLibrary.launch(entry.id, entry.name)
    else entry.execute()
  }

  function activate(row) {
    if (row.toplevels.length === 0) {
      root.launch(row)
      return
    }
    if (root.allMinimized(row)) {
      root.restore(row.toplevels[0])
      return
    }

    var active = ToplevelManager.activeToplevel
    // Clicking the app you are already in puts it away. This is the mouse's
    // minimize: the titlebar button cannot be one, so the dock has to be.
    if (row.toplevels.length === 1 && row.toplevels[0] === active) {
      root.minimize(active)
      return
    }

    var target = Model.nextWindow(row.toplevels, active)
    if (!target) return
    if (root.isMinimized(target)) root.restore(target)
    else root.focusWindow(target)
  }

  function togglePin(row) {
    if (!pinFile.adapter) return
    pinFile.adapter.apps = Model.togglePin(root.pinnedIds, row.appId)
    pinFile.writeAdapter()
  }

  // Which apps sit in the dock when nothing is running. Right-click an icon to
  // add or remove one; the file is the record after that.
  FileView {
    id: pinFile

    path: root.home + "/.local/state/pneuma/dock.json"
    watchChanges: true
    printErrors: false
    // No file on first run -- writing the defaults creates it.
    onLoadFailed: pinFile.writeAdapter()

    JsonAdapter {
      property list<string> apps: [
        "app.zen_browser.zen",
        "org.gnome.Nautilus",
        "org.mozilla.Thunderbird",
        "com.spotify.Client",
        "com.slack.Slack"
      ]
    }
  }

  // Presence of the flag file = easy mode on. Watching the directory rather
  // than the file because FileView cannot observe a file that does not exist
  // yet, and `easy-mode` creates and removes exactly that file.
  Process {
    id: easyModeProbe

    running: true
    command: ["bash", "-c", "[[ -f " + root.easyModeFlag + " ]] && echo yes || echo no"]
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
    onFileChanged: easyModeProbe.running = true
  }

  IpcHandler {
    target: "pneuma.dock"

    function state(): string {
      return JSON.stringify({
        easyMode: root.easyMode,
        pinned: root.pinnedIds,
        rows: root.rows.map(function (row) {
          return {
            appId: row.appId,
            pinned: row.pinned,
            windows: row.toplevels.length,
            minimized: root.allMinimized(row)
          }
        })
      })
    }
  }

  Variants {
    model: Quickshell.screens

    PanelWindow {
      id: panel

      required property var modelData

      screen: panel.modelData
      visible: root.easyMode
      color: "transparent"
      WlrLayershell.namespace: "pneuma-dock"
      WlrLayershell.layer: WlrLayer.Top
      WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

      anchors {
        bottom: true
        left: true
        right: true
      }

      implicitHeight: bar.height + root.edgeGap + root.headroom
      // Windows are kept off the dock itself, not off the label headroom.
      exclusiveZone: bar.height + root.edgeGap
      // Everything outside the bar -- the headroom, and the gaps either side of
      // a centred dock -- stays clickable through to the window underneath.
      mask: Region {
        item: bar
      }

      // The same material as the switcher and the OSD: the popup surface on one
      // soft drop shadow, frosted by the pneuma-dock layer rule in
      // hypr/toggles/easy-mode.lua.
      RectangularShadow {
        anchors.fill: bar
        radius: bar.radius
        blur: Style.space(28)
        offset.y: Style.space(6)
        color: Qt.rgba(0, 0, 0, 0.3)
      }

      BorderSurface {
        id: bar

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: root.edgeGap
        width: row.implicitWidth + root.barPad * 2 + borderLeft + borderRight
        height: row.implicitHeight + root.barPad * 2 + borderTop + borderBottom
        radius: Style.cornerRadius
        color: Color.popups.background
        borderSpec: Border.surfaceSpec("popups", "border", Color.popups.border, Math.max(1, Style.space(2)))

        Row {
          id: row

          x: bar.borderLeft + root.barPad
          y: bar.borderTop + root.barPad
          spacing: Style.space(6)

          Repeater {
            model: root.rows

            Row {
              id: cell

              required property var modelData
              required property int index

              // One divider, where the pinned apps stop and the rest begin.
              readonly property bool divider: Model.startsRunningSection(root.rows, cell.index)

              spacing: cell.divider ? Style.space(6) : 0

              Rectangle {
                visible: cell.divider
                width: cell.divider ? 1 : 0
                height: dockItem.implicitHeight
                color: Util.alpha(Color.popups.text, 0.18)
              }

              DockItem {
                id: dockItem

                row: cell.modelData
                iconSize: root.iconSize
                appLibrary: root.appLibrary
                minimized: root.allMinimized(cell.modelData)
                active: root.isActiveRow(cell.modelData)
                onChosen: root.activate(cell.modelData)
                onSecondary: root.togglePin(cell.modelData)
              }
            }
          }
        }
      }
    }
  }
}
