import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.Commons
import qs.Ui
import "OverviewModel.js" as Model

// Mission Control: swiping up spreads the workspaces out as a grid of live
// miniatures, swiping down puts them back, and the grid follows the fingers
// the whole way rather than snapping at the end.
//
// The compositor half is three live gestures in hypr/input.lua that forward
// nothing but raw finger travel over socket2. Every bit of state -- whether
// the overview is up, how far the swipe has carried it -- lives here, so a
// `hyprctl reload` cannot leave the two halves disagreeing about what is on
// screen, and Escape or a click can close it without the gesture ever knowing.
Item {
  id: root

  readonly property string channel: "overview>>"
  // How far a finger has to travel to carry the overview all the way open.
  // Short enough that the flick a Mac user already has in their hands lands.
  readonly property int travelToOpen: 240

  // The single source of truth for every visual: 0 is the bare desktop, 1 the
  // settled grid, and a live gesture drives the values in between.
  property real progress: 0
  property bool opened: false
  property string dragging: ""  // "up", "down", or "" when no gesture is live

  // Only while nothing is being dragged, so the grid tracks the fingers one
  // to one and animates only when it is left to settle on its own.
  Behavior on progress {
    enabled: root.dragging === ""
    NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
  }

  function settle(open) {
    root.dragging = ""
    root.opened = open
    root.progress = open ? 1 : 0
    // Window geometry is what places every thumbnail, and tiling moves windows
    // without Hyprland volunteering their new boxes. Asking once the overview
    // has shut, rather than as it opens, keeps the answer from landing in the
    // middle of a swipe: it arrives as a new toplevel list, which rebuilds
    // every thumbnail, which is a visible hitch if anything is moving.
    if (!open) Hyprland.refreshToplevels()
  }

  function drag(distance) {
    if (root.dragging === "") return
    var from = root.opened ? 1 : 0
    var direction = root.dragging === "up" ? 1 : -1
    root.progress = Model.clamp01(from + direction * distance / root.travelToOpen)
  }

  function handle(message) {
    if (message === "start:up") {
      if (!root.opened) root.dragging = "up"
    } else if (message === "start:down") {
      if (root.opened) root.dragging = "down"
    } else if (message.indexOf("move:") === 0) {
      root.drag(Number(message.substring(5)))
    } else if (message.indexOf("end:") === 0) {
      if (root.dragging === "") return
      // A gesture the backend killed mid-swipe leaves things as they were;
      // one the user finished goes wherever it was carried past halfway.
      root.settle(message === "end:1" ? root.opened : root.progress > 0.5)
    }
  }

  // Focus alone does not raise a floating window: focusing four different
  // windows in turn on this desktop never changed which one was drawn on top.
  // So a clicked thumbnail has to be lifted as well, or the window you picked
  // keeps its place in the pile and the click reads as having done nothing.
  //
  // Both are aimed at the window by address rather than at whatever happens to
  // be active, so neither depends on the other having landed first. Focus also
  // carries you to the window's workspace when it is on another one.
  function choose(toplevel) {
    root.settle(false)
    if (!toplevel) return
    var target = 'hl.get_window("address:0x' + toplevel.address + '")'
    Hyprland.dispatch("hl.dsp.focus({ window = " + target + " })")
    Hyprland.dispatch("hl.dsp.window.bring_to_top({ window = " + target + " })")
  }

  function show(workspace) {
    root.settle(false)
    if (workspace) workspace.activate()
  }

  Connections {
    target: Hyprland

    // Hyprland stamps every `hl.dsp.event` payload with its own `custom`
    // name, so the channel this reads for is the head of the data.
    function onRawEvent(event) {
      if (String(event.name) !== "custom") return
      var data = String(event.data)
      if (data.indexOf(root.channel) !== 0) return
      root.handle(data.substring(root.channel.length))
    }
  }

  IpcHandler {
    target: "pneuma.overview"

    function toggle(): string { root.settle(!root.opened); return "ok" }
    function state(): string {
      return JSON.stringify({
        opened: root.opened,
        progress: root.progress,
        dragging: root.dragging
      })
    }
  }

  Variants {
    model: Quickshell.screens

    PanelWindow {
      id: panel

      required property var modelData

      readonly property var hyprMonitor: Hyprland.monitorFor(panel.modelData)
      readonly property var tiles: Model.gridWorkspaces(Hyprland.workspaces.values,
        String(panel.modelData.name))

      screen: panel.modelData
      visible: root.progress > 0.001
      anchors { top: true; bottom: true; left: true; right: true }
      color: "transparent"
      WlrLayershell.namespace: "pneuma-overview"
      WlrLayershell.layer: WlrLayer.Overlay
      // Taken only once the overview has settled open: a swipe the user
      // abandons must not have stolen the keyboard from what they were typing.
      WlrLayershell.keyboardFocus: root.opened && root.dragging === ""
        ? WlrKeyboardFocus.Exclusive
        : WlrKeyboardFocus.None
      exclusionMode: ExclusionMode.Ignore

      // Deep enough that the desktop, the bar and the dock all fall away
      // behind the grid, which is the whole point of standing back from them.
      Rectangle {
        anchors.fill: parent
        color: Color.background
        opacity: root.progress * 0.92
      }

      // A click on the space around the grid closes it, same as the desktop
      // click that closes the switcher.
      MouseArea {
        anchors.fill: parent
        onClicked: root.settle(false)
      }

      Item {
        anchors.fill: parent
        focus: true

        Keys.onPressed: function (event) {
          if (event.key !== Qt.Key_Escape) return
          root.settle(false)
          event.accepted = true
        }
      }

      Repeater {
        model: panel.tiles

        WorkspaceTile {
          id: slot

          required property var modelData
          required property int index

          readonly property var resting: Model.tileRect(slot.index, panel.tiles.length,
            panel.width, panel.height, Style.space(20), Style.space(56),
            panel.height > 0 ? panel.width / panel.height : 1.6)
          // Where the tile comes from. The workspace you are on grows out of
          // the whole screen it is covering, which is what makes the swipe
          // read as the desktop shrinking rather than a panel appearing over
          // it; the rest ease up from just under their resting size.
          readonly property var entry: slot.modelData.active
            ? ({ x: 0, y: 0, width: panel.width, height: panel.height })
            : ({
                x: slot.resting.x + slot.resting.width * 0.04,
                y: slot.resting.y + slot.resting.height * 0.04,
                width: slot.resting.width * 0.92,
                height: slot.resting.height * 0.92
              })

          workspace: slot.modelData
          monitor: panel.hyprMonitor
          capturing: panel.visible
          active: slot.modelData.active
          progress: root.progress

          // Laid out once at its resting size and scaled from there. Binding
          // width and height to the swipe instead would relayout the tile's
          // whole contents on every frame of it -- see WorkspaceTile.
          width: slot.resting.width
          height: slot.resting.height
          transformOrigin: Item.TopLeft
          x: Model.lerp(slot.entry.x, slot.resting.x, root.progress)
          y: Model.lerp(slot.entry.y, slot.resting.y, root.progress)
          scale: Model.lerp(slot.entry.width / slot.resting.width, 1, root.progress)
          opacity: slot.modelData.active ? 1 : root.progress

          onWindowChosen: function (toplevel) { root.choose(toplevel) }
          onChosen: root.show(slot.modelData)
        }
      }
    }
  }
}
