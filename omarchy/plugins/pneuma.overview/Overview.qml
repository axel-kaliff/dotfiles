import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.Commons
import qs.Ui
import "OverviewModel.js" as Model

// Mission Control: swiping up spreads the windows on the workspace you are on
// far enough apart that none covers another, swiping down puts them back, and
// they follow the fingers the whole way rather than snapping at the end.
// Clicking one focuses it, raises it, and dismisses the overview.
//
// The compositor half is three live gestures in hypr/input.lua that forward
// nothing but raw finger travel over socket2. Every bit of state -- whether
// the overview is up, how far the swipe has carried it -- lives here, so a
// `hyprctl reload` cannot leave the two halves disagreeing about what is on
// screen, and Escape or a click can close it without the gesture knowing.
Item {
  id: root

  readonly property string channel: "overview>>"
  // How far a finger has to travel to carry the overview all the way open.
  // Short enough that the flick a Mac user already has in their hands lands.
  readonly property int travelToOpen: 240
  readonly property int settleDuration: 220

  // The single source of truth for every visual: 0 is the bare desktop, 1 the
  // settled spread, and a live gesture drives the values in between.
  property real progress: 0
  property bool opened: false
  property string dragging: ""  // "up", "down", or "" when no gesture is live

  // Windows come apart ahead of the swipe rather than in step with it: eased
  // this way they are already legible around the halfway mark, where a linear
  // separation still has them piled up at exactly the moment you are looking.
  readonly property real separation: 1 - Math.pow(1 - root.progress, 3)

  // Animated only when the overview is left to settle on its own, so that
  // during a gesture the windows track the fingers one to one.
  Behavior on progress {
    enabled: root.dragging === ""
    NumberAnimation { duration: root.settleDuration; easing.type: Easing.OutCubic }
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

  // Picking a window has to wait for the overview to be gone. An exclusive
  // keyboard-focus layer takes the focus outright -- while the overview is up
  // Hyprland reports no active window at all -- so a focus dispatched from
  // under it is swallowed, and when the layer goes away Hyprland hands the
  // focus back to whatever held it before, overwriting anything set in the
  // meantime. Measured: clicking a thumbnail produced no activewindow event
  // for the clicked window at all, only a restore to the previous one.
  //
  // So the choice is remembered, the overview dismissed, and the window acted
  // on once the overlay has actually let go of the keyboard.
  property var pending: null

  function choose(toplevel) {
    root.pending = toplevel
    root.settle(false)
    if (toplevel) handover.restart()
  }

  Timer {
    id: handover

    // Just past the close, so the layer is down before the window is touched.
    interval: root.settleDuration + 60

    onTriggered: {
      var toplevel = root.pending
      root.pending = null
      if (!toplevel) return
      // Focus alone does not raise a floating window -- focusing four windows
      // in turn never changed which was drawn on top -- so the pick is lifted
      // as well, or it stays buried and the click reads as having done nothing.
      var target = 'hl.get_window("address:0x' + toplevel.address + '")'
      Hyprland.dispatch("hl.dsp.focus({ window = " + target + " })")
      Hyprland.dispatch("hl.dsp.window.bring_to_top({ window = " + target + " })")
    }
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
      // Only the workspace you are on. Its windows are the ones already in
      // front of you, and spreading just those is what keeps each thumbnail
      // big enough to pick out at a glance.
      readonly property var workspace: panel.hyprMonitor ? panel.hyprMonitor.activeWorkspace : null
      readonly property int margin: Style.space(56)

      // Each window with both of its boxes worked out in the same pass: where
      // it really is, and the slot it spreads into. Deriving them together is
      // what makes it impossible to index one apart from the other, and
      // neither depends on the swipe, so the list below stays put while the
      // gesture runs -- rebuilding it would restart every screen capture.
      //
      // A window Hyprland has not described yet is simply not in the list --
      // `lastIpcObject` is an empty, and so still truthy, map until it has
      // been, which is why the geometry itself is what gets checked.
      readonly property var placed: {
        if (!panel.hyprMonitor || panel.width <= 0) return []
        var all = panel.workspace && panel.workspace.toplevels
          ? panel.workspace.toplevels.values : []

        var described = []
        for (var i = 0; i < all.length; i++) {
          var box = all[i].lastIpcObject
          if (!box || !box.at || !box.size) continue
          described.push({ toplevel: all[i], at: box.at, size: box.size })
        }

        var screen = { x: 0, y: 0, width: panel.width, height: panel.height }
        var room = {
          x: panel.margin,
          y: panel.margin,
          width: Math.max(1, panel.width - panel.margin * 2),
          height: Math.max(1, panel.height - panel.margin * 2)
        }
        var spread = Model.exposeRects(described, room, Style.space(16))
        for (var j = 0; j < described.length; j++) {
          // Against the whole screen, so at rest the thumbnail sits exactly
          // over the window it stands for and the swipe starts from nothing.
          described[j].actual = Model.windowRect(described[j].at, described[j].size,
            panel.hyprMonitor, screen)
          described[j].target = spread[j]
        }
        return described
      }

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
      // behind the windows, which is the whole point of standing back.
      Rectangle {
        anchors.fill: parent
        color: Color.background
        opacity: root.progress * 0.92
      }

      // A click on the space around the windows closes it, same as the
      // desktop click that closes the switcher.
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
        model: panel.placed

        // Built at the size it rests at, then moved and scaled into place.
        // Both boxes carry the same window aspect, so a uniform scale is the
        // exact interpolation between them -- and binding width and height to
        // the swipe instead would relayout, and restart the capture, every
        // frame of the gesture.
        Item {
          id: thumbnail

          required property var modelData

          width: thumbnail.modelData.target.width
          height: thumbnail.modelData.target.height
          transformOrigin: Item.TopLeft
          x: Model.lerp(thumbnail.modelData.actual.x, thumbnail.modelData.target.x, root.separation)
          y: Model.lerp(thumbnail.modelData.actual.y, thumbnail.modelData.target.y, root.separation)
          scale: Model.lerp(thumbnail.modelData.actual.width / thumbnail.modelData.target.width,
            1, root.separation)

          ScreencopyView {
            anchors.fill: parent
            captureSource: panel.visible ? thumbnail.modelData.toplevel.wayland : null
            live: true
            paintCursor: false
          }

          // Says which window a click is about to land on.
          Rectangle {
            anchors.fill: parent
            color: "transparent"
            radius: Math.max(0, Style.cornerRadius - Style.space(4))
            border.width: Math.max(1, Style.space(2))
            border.color: picker.containsMouse ? Style.hoverBorderColor : "transparent"
          }

          MouseArea {
            id: picker

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.choose(thumbnail.modelData.toplevel)
          }
        }
      }
    }
  }
}
