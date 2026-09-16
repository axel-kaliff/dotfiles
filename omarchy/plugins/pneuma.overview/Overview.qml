import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.Commons
import qs.Ui
import "OverviewModel.js" as Model

// Mission Control: swiping up slides in a strip of miniature workspaces --
// every workspace on the monitor side by side, each a small live desktop --
// and swiping down puts it away. Clicking a workspace switches to it,
// clicking a window focuses that window, and dragging a window onto another
// workspace moves it there. The strip always ends on an empty workspace, so
// a drag can put a window somewhere that does not exist yet.
//
// The shape is Hyprspace's (github.com/KZDKM/Hyprspace), rebuilt here rather
// than installed: Hyprspace is a compositor plugin, it does not build against
// Hyprland 0.56 (its issue #239), and hyprpm cannot build anything on this
// machine. Its gestures also hang off `gestures:workspace_swipe`, which 0.56
// deleted outright.
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

  // Hyprspace's own defaults (src/main.cpp): a 250px strip of miniatures with
  // 12px between them, scaled here the way every other length in the shell is.
  readonly property int panelHeight: Style.space(250)
  readonly property int workspaceMargin: Style.space(12)
  // Hyprspace's dragAlpha: what a window fades to where it used to be, so the
  // one under the cursor reads as the one being placed.
  readonly property real dragAlpha: 0.2
  // How far the spread below the strip insets from the screen edge.
  readonly property int exposeMargin: Style.space(56)
  // Hyprspace's click-to-exit timeout: a press and release further apart than
  // this was a drag that ended over nothing, not a click meaning "close".
  readonly property int clickMillis: 200

  // The single source of truth for every visual: 0 is the bare desktop, 1 the
  // settled strip, and a live gesture drives the values in between.
  property real progress: 0
  property bool opened: false
  property string dragging: ""  // "up", "down", or "" when no gesture is live

  // Raising the panel is the slow half of opening the overview: a fresh layer
  // surface costs a configure round-trip, a scene graph, and a screencopy
  // session per window. Armed means the panel is up and holding at progress 0,
  // where the strip is still off the top of the screen and there is nothing to
  // see. The cost is paid there, before anything moves.
  property bool armed: false

  // The strip comes down ahead of the swipe rather than in step with it: eased
  // this way it is already readable around the halfway mark, where a linear
  // slide still has it mostly off screen at exactly the moment you are looking.
  readonly property real slide: 1 - Math.pow(1 - root.progress, 3)

  // Animated only when the overview is left to settle on its own, so that
  // during a gesture the strip tracks the fingers one to one.
  Behavior on progress {
    enabled: root.dragging === ""
    NumberAnimation { id: settling; duration: root.settleDuration }
  }

  function settle(open) {
    // `slide` eases the strip in on its own, so an ease-out here compounds
    // into a snap. Opening from rest is eased in and left to the slide to ease
    // out, which is one smooth curve across the whole 220ms. Closing runs that
    // pair backwards, where an ease-out is already the gentle end, and a swipe
    // let go mid-flight is moving anyway, so it carries on and decelerates.
    var resting = root.progress === 0 || root.progress === 1
    settling.easing.type = open && resting ? Easing.InCubic : Easing.OutCubic
    root.dragging = ""
    root.opened = open
    root.progress = open ? 1 : 0
    // A swipe that began and died without travel leaves progress where it
    // already was, so no animation will carry the overview home for us.
    if (!open && root.progress === 0) root.rest()
  }

  // One entry per screen, each panel adding and removing itself, so unplugging
  // a monitor cannot leave a destroyed panel behind that is never ready again.
  // `Variants.instances` looked like the way to avoid keeping this by hand and
  // is not: it read as empty every time, which silently turned the check below
  // into "no panels, so everyone is ready".
  property var panels: []

  function enrol(panel, joining) {
    var kept = []
    for (var i = 0; i < root.panels.length; i++) {
      if (root.panels[i] !== panel) kept.push(root.panels[i])
    }
    if (joining) kept.push(panel)
    root.panels = kept
  }

  // Called by a panel once every thumbnail it shows has a frame to draw. The
  // strip waits for every screen: a monitor with nothing on it is ready the
  // instant it is laid out, and left to speak for the whole overview it slid
  // the strip in over another screen's blank boxes -- measured, one screen had
  // 6 of its 7 thumbnails when that happened.
  function warmed() {
    if (!root.armed || root.opened || root.dragging !== "") return
    for (var i = 0; i < root.panels.length; i++) {
      if (!root.panels[i].ready) return
    }
    deadline.stop()
    root.settle(true)
  }

  onArmedChanged: if (root.armed) deadline.restart(); else deadline.stop()

  Timer {
    id: deadline

    // A capture that never arrives -- a window that has stopped drawing, say --
    // must not hold the overview off the screen for good. Long enough that the
    // usual case, 30ms from armed to the first frames, is never cut short.
    interval: 400
    onTriggered: if (root.armed && !root.opened && root.dragging === "") root.settle(true)
  }

  // None of the overview is on screen any more: the panel comes down, and the
  // geometry the next one is laid out from is asked for. Window geometry is
  // what places every thumbnail, and tiling moves windows without Hyprland
  // volunteering their new boxes; asking here rather than while the overview
  // opens keeps the answer -- a new toplevel list, which rebuilds every
  // thumbnail -- out of the middle of anything moving.
  function rest() {
    root.armed = false
    Hyprland.refreshToplevels()
  }

  // Not while a gesture is live: a swipe down carried past the desktop sits at
  // 0 with the fingers still on the pad, and taking the panel away there
  // leaves nothing to show if they come back up.
  onProgressChanged: if (root.progress === 0 && root.dragging === "") root.rest()

  function drag(distance) {
    if (root.dragging === "") return
    var from = root.opened ? 1 : 0
    var direction = root.dragging === "up" ? 1 : -1
    root.progress = Model.clamp(from + direction * distance / root.travelToOpen, 0, 1)
  }

  function handle(message) {
    if (message === "start:up") {
      if (root.opened) return
      root.dragging = "up"
      // Fingers down, nothing carried yet: the cheapest moment there is to pay
      // for the panel, and the travel that follows covers what is left of it.
      root.armed = true
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

  // What to run once the overview has actually let go of the keyboard. An
  // exclusive keyboard-focus layer takes the focus outright -- while the
  // overview is up Hyprland reports no active window at all -- so a dispatch
  // sent from under it is swallowed, and when the layer goes away Hyprland
  // hands focus back to whatever held it before, overwriting anything set in
  // the meantime. Measured: clicking a thumbnail produced no activewindow
  // event for the clicked window at all, only a restore to the previous one.
  property var pending: []

  function commit(dispatches) {
    root.pending = dispatches
    root.settle(false)
    handover.restart()
  }

  // Kept past the handover: in an expose the pick has to collapse in front of
  // the others, or it slides back underneath one of them on the way down and
  // the window that was clicked is the one you cannot see. Spread thumbnails
  // never overlap, so this only has any effect while they are in motion.
  property var raised: null

  // Focus alone does not raise a floating window -- focusing four windows in
  // turn never changed which was drawn on top -- so the pick is lifted as
  // well, or it stays buried and the click reads as having done nothing.
  function choose(toplevel) {
    root.raised = toplevel
    var target = 'hl.get_window("address:0x' + toplevel.address + '")'
    root.commit(["hl.dsp.focus({ window = " + target + " })",
      "hl.dsp.window.bring_to_top({ window = " + target + " })"])
  }

  // A plain integer is enough, and is the only form that works for the empty
  // slot at the end of the strip: Hyprland creates the workspace on the way in,
  // where `hl.get_workspace(id)` would only have returned nil.
  function switchTo(workspaceId) {
    root.commit(["hl.dsp.focus({ workspace = " + workspaceId + " })"])
  }

  Timer {
    id: handover

    // Only long enough for the compositor to see the overview let go of the
    // keyboard, which happens the instant `opened` goes false -- not for the
    // close animation to finish. Waiting out the animation left a visible
    // pause after the strip had gone; two frames is under the eye. Measured: a
    // dispatch as little as a round-trip after the close begins already
    // sticks, while one sent a moment before it is swallowed whole.
    interval: 32

    onTriggered: {
      var dispatches = root.pending
      root.pending = []
      for (var i = 0; i < dispatches.length; i++) Hyprland.dispatch(dispatches[i])
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

    function toggle(): string {
      // No fingers to cover the wait, so this only raises the panel; what it
      // shows follows once the captures have pixels (see `armed`).
      if (root.opened || root.armed) root.settle(false)
      else root.armed = true
      return "ok"
    }
    // The state machine, for driving the overview from a terminal when there
    // is no touchpad to hand: `omarchy-shell pneuma.overview state`. The
    // capture counts are here because "it opened" and "it opened with every
    // thumbnail drawn" are different answers, and only the second one is good.
    function state(): string {
      var screens = []
      for (var i = 0; i < root.panels.length; i++) {
        var p = root.panels[i]
        screens.push({ monitor: p.modelData.name, warm: p.warm, captures: p.captures,
          ready: p.ready })
      }
      return JSON.stringify({
        opened: root.opened,
        progress: root.progress,
        dragging: root.dragging,
        screens: screens
      })
    }
  }

  Variants {
    id: screens

    model: Quickshell.screens

    PanelWindow {
      id: panel

      required property var modelData

      readonly property var hyprMonitor: Hyprland.monitorFor(panel.modelData)

      // One entry per workspace the strip shows: its box, the workspace behind
      // it where there is one, and the windows in it with their place inside
      // that box. Worked out when the panel goes up, not bound: as a binding it
      // was re-evaluated on every frame of the animation, which hands the
      // Repeater a new model each time, and a rebuilt thumbnail loses its
      // capture.
      property var slots: []
      // The expose's tiles: one per window on the current workspace, each with
      // where it really sits and the slot it spreads into.
      property var spread: []
      // The same boxes on their own, for the hit test that runs on every frame
      // of a drag -- rebuilding that list per frame is allocation on the one
      // path that cannot afford it.
      property var boxes: []

      // How far the strip is panned and how far it may be. A transform on the
      // whole strip, never a relayout, for the same reason.
      property real pan: 0
      property real panLimit: 0

      // Thumbnails that have a frame to draw, against how many there are.
      // What the overview waits on before it slides in: see `armed`.
      property int warm: 0
      property int captures: 0
      property bool ready: false

      // The window being carried to another workspace, once the press has
      // travelled far enough to be a drag rather than a click.
      property var holding: null
      property rect ghost: Qt.rect(0, 0, 0, 0)
      // How tall the carried window is drawn: about a workspace thumbnail's
      // worth, so a drag reads as putting the window into one of those rather
      // than sliding a full-size window around. The width follows the window's
      // own aspect, because a squashed thumbnail stops looking like the window.
      readonly property int ghostHeight: Style.space(180)
      property int dropTarget: -1

      // Hyprland's own stacking, which is Hyprspace's too: tiled windows at the
      // bottom, floating above them, and the one focused last on top of those,
      // so a miniature reads the way the desktop it stands for does.
      //
      // Rects come out relative to the box, because each workspace clips its
      // own windows and a clip has to be the windows' parent.
      function windowsIn(workspace, box, counted) {
        if (!workspace || !workspace.toplevels) return []

        var area = { x: 0, y: 0, width: box.width, height: box.height }
        var all = workspace.toplevels.values
        var built = []
        var front = null

        for (var i = 0; i < all.length; i++) {
          var ipc = all[i].lastIpcObject
          // A window Hyprland has not described yet is simply left out:
          // `lastIpcObject` is an empty, and so still truthy, map until it has
          // been, which is why the geometry itself is what gets checked.
          if (!ipc || !ipc.at || !ipc.size) continue

          var entry = {
            toplevel: all[i],
            // Waited on only if it can be seen and can be captured at all.
            counted: counted && Model.onMonitor(ipc.at, ipc.size, panel.hyprMonitor),
            depth: ipc.floating ? 1 : 0,
            rect: Model.windowRect(ipc.at, ipc.size, panel.hyprMonitor, area)
          }
          if (ipc.floating && (front === null || ipc.focusHistoryID < front.order)) {
            front = { entry: entry, order: ipc.focusHistoryID }
          }
          built.push(entry)
        }

        if (front) front.entry.depth = 2
        return built
      }

      // The current workspace's windows, each with both of its boxes worked
      // out in the same pass: where it really is, and the slot it spreads into.
      // Deriving them together is what makes it impossible to index one apart
      // from the other, and neither depends on the swipe, so the list stays put
      // while the gesture runs -- rebuilding it would restart every capture.
      function layOutExpose() {
        var workspace = panel.hyprMonitor.activeWorkspace
        var all = workspace && workspace.toplevels ? workspace.toplevels.values : []

        var described = []
        for (var i = 0; i < all.length; i++) {
          var ipc = all[i].lastIpcObject
          if (!ipc || !ipc.at || !ipc.size) continue
          described.push({ toplevel: all[i], at: ipc.at, size: ipc.size,
            counted: Model.onMonitor(ipc.at, ipc.size, panel.hyprMonitor) })
        }

        var screen = { x: 0, y: 0, width: panel.width, height: panel.height }
        // Under the strip, the way GNOME stacks the two: workspaces along the
        // top, the workspace you are on spread out beneath them.
        var top = root.panelHeight + root.exposeMargin
        var room = {
          x: root.exposeMargin,
          y: top,
          width: Math.max(1, panel.width - root.exposeMargin * 2),
          height: Math.max(1, panel.height - top - root.exposeMargin)
        }
        var slotted = Model.exposeRects(described, room, Style.space(16))
        for (var j = 0; j < described.length; j++) {
          // Against the whole screen, so at rest the thumbnail sits exactly
          // over the window it stands for and the swipe starts from nothing.
          described[j].actual = Model.windowRect(described[j].at, described[j].size,
            panel.hyprMonitor, screen)
          described[j].target = slotted[j]
        }
        return described
      }

      function relayout(recentre) {
        if (!panel.hyprMonitor || panel.width <= 0) return

        var mine = []
        var elsewhere = []
        var all = Hyprland.workspaces ? Hyprland.workspaces.values : []
        for (var i = 0; i < all.length; i++) {
          if (all[i].id < 1) continue
          if (all[i].monitor === panel.hyprMonitor) mine.push(all[i])
          else elsewhere.push(all[i].id)
        }

        var occupied = []
        for (var m = 0; m < mine.length; m++) occupied.push(mine[m].id)

        var ids = Model.stripWorkspaces(occupied, elsewhere)
        var laid = Model.stripLayout(ids.length, { width: panel.width, height: panel.height },
          root.panelHeight, root.workspaceMargin)

        panel.panLimit = laid.limit

        // Only on the way in. Hyprspace centres the whole group and leaves it
        // there -- its autoScroll option is declared and then never read --
        // which puts the workspace you are on off the left edge the moment the
        // strip outgrows the screen: workspace 2 of 9 opened at x=-482 on a
        // 3440 screen. Centring on the current workspace is what that option
        // was for. Doing it on every relayout would instead yank the strip out
        // from under the pointer each time a window was dropped somewhere.
        var middle = panel.pan
        var active = panel.hyprMonitor.activeWorkspace
        if (recentre && active) {
          for (var a = 0; a < ids.length; a++) {
            if (ids[a] === active.id) {
              middle = panel.width / 2 - (laid.boxes[a].x + laid.boxes[a].width / 2)
            }
          }
        }
        panel.pan = Model.clamp(middle, -laid.limit, laid.limit)

        // Built after the pan settles, because whether a workspace is on screen
        // decides whether the strip waits for its thumbnails. A strip wider than
        // the monitor keeps boxes past the edge, and a capture for a tile that is
        // never painted never starts: waiting on one pinned the strip at 6 of 7
        // for as long as it was open, and only the 400ms deadline ever got it up.
        // Panning to such a box fills it in then.
        var built = []
        var total = 0
        for (var slot = 0; slot < ids.length; slot++) {
          var workspace = null
          for (var w = 0; w < mine.length; w++) if (mine[w].id === ids[slot]) workspace = mine[w]

          var box = laid.boxes[slot]
          var onScreen = box.x + panel.pan < panel.width && box.x + box.width + panel.pan > 0
          var windows = panel.windowsIn(workspace, box, onScreen)
          // Each window decides for itself, so a box that is on screen but
          // holds one window scrolled off the monitor contributes only the
          // thumbnails that will actually arrive.
          for (var c = 0; c < windows.length; c++) if (windows[c].counted) total++
          built.push({ id: ids[slot], workspace: workspace, box: box, windows: windows })
        }

        var flying = panel.layOutExpose()
        for (var f = 0; f < flying.length; f++) if (flying[f].counted) total++

        panel.warm = 0
        panel.captures = total
        panel.ready = total === 0
        panel.boxes = laid.boxes
        panel.slots = built
        panel.spread = flying
        // A monitor with nothing on it anywhere has no capture to wait for.
        if (panel.ready) root.warmed()
      }

      // The overview stays up after a drop: Hyprspace leaves you in the strip
      // (its switchOnDrop is off by default), so several windows can be moved
      // in one visit. Dispatched straight away rather than through the
      // handover -- a drag has already released the keyboard, so there is
      // nothing to be swallowed by.
      function moveWindow(toplevel, workspaceId) {
        Hyprland.dispatch('hl.dsp.window.move({ window = hl.get_window("address:0x'
          + toplevel.address + '"), workspace = ' + workspaceId + ' })')
        Hyprland.refreshToplevels()
        retile.restart()
      }

      Timer {
        id: retile

        // Long enough for the compositor to have re-tiled both workspaces and
        // told Quickshell about it. A relayout restarts every capture, so it
        // happens once, after the move, rather than per reported change.
        interval: 120
        onTriggered: if (panel.visible) panel.relayout(false)
      }

      // Captures stop with the panel and report their first frame again when it
      // comes back, so what was warm before it went away counts for nothing.
      onVisibleChanged: {
        panel.warm = 0
        panel.ready = false
        if (panel.visible) panel.relayout(true)
      }
      onWidthChanged: if (panel.visible) panel.relayout(true)
      onHeightChanged: if (panel.visible) panel.relayout(true)

      Component.onCompleted: root.enrol(panel, true)
      Component.onDestruction: root.enrol(panel, false)

      Region { id: untouchable }

      screen: panel.modelData
      visible: root.armed
      anchors { top: true; bottom: true; left: true; right: true }
      color: "transparent"
      // An armed overview stands invisibly in front of the windows, so until
      // it has something to show it takes no pointer from them either.
      mask: root.progress > 0 ? null : untouchable
      WlrLayershell.namespace: "pneuma-overview"
      WlrLayershell.layer: WlrLayer.Overlay
      // Taken only once the overview has settled open, and given up again for
      // the length of a drag: a swipe the user abandons must not have stolen
      // the keyboard from what they were typing, and a dispatch aimed at a
      // window is swallowed while this layer holds the focus exclusively.
      WlrLayershell.keyboardFocus: root.opened && root.dragging === "" && panel.holding === null
        ? WlrKeyboardFocus.Exclusive
        : WlrKeyboardFocus.None
      exclusionMode: ExclusionMode.Ignore

      // Deep behind an expose, which covers the screen and wants the desktop,
      // the bar and the dock to fall away entirely. Only a wash behind the
      // strip: unlike Hyprspace this cannot hide the bar and the dock outright,
      // and at the 0.92 the spread wants, a 250px band of miniatures was the
      // only thing left to look at on an otherwise unreadable screen.
      Rectangle {
        anchors.fill: parent
        color: Color.background
        opacity: root.progress * 0.92
      }

      // A click on the space around the strip closes it, same as the desktop
      // click that closes the switcher.
      MouseArea {
        anchors.fill: parent

        property double pressedAt: 0

        onPressed: pressedAt = Date.now()
        // Hyprspace's rule: only a quick press and release means "close", so
        // letting go of a drag that ended over nothing does not also dismiss.
        onReleased: if (Date.now() - pressedAt < root.clickMillis) root.settle(false)
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

      Item {
        id: strip

        width: panel.width
        height: root.panelHeight
        // The whole strip slides down from off the top of the screen. Moving
        // one item is the entire open animation: nothing is laid out again, so
        // no capture is restarted on the way in.
        y: Model.lerp(-root.panelHeight, 0, root.slide)

        // The strip's own ground, so it reads as a panel laid over the desktop
        // rather than a few boxes adrift in a dimmed screen. Hyprspace reserves
        // this band from the layout outright; a layer surface cannot, so the
        // band is painted instead.
        Rectangle {
          anchors.fill: parent
          color: Util.alpha(Color.background, 0.85)
        }

        // Under the workspaces so it never eats a click; it takes no buttons,
        // only the wheel, which the boxes above it do not handle.
        MouseArea {
          anchors.fill: parent
          acceptedButtons: Qt.NoButton

          onWheel: function (wheel) {
            var step = wheel.angleDelta.x !== 0 ? wheel.angleDelta.x : wheel.angleDelta.y
            panel.pan = Model.clamp(panel.pan + step, -panel.panLimit, panel.panLimit)
          }
        }

        Item {
          id: panned

          width: strip.width
          height: strip.height
          x: panel.pan

          Repeater {
            model: panel.slots

            Item {
              id: space

              required property var modelData
              required property int index

              x: space.modelData.box.x
              y: space.modelData.box.y
              width: space.modelData.box.width
              height: space.modelData.box.height

              readonly property bool current: !!space.modelData.workspace && !!panel.hyprMonitor
                && panel.hyprMonitor.activeWorkspace === space.modelData.workspace
              readonly property bool wanted: panel.dropTarget === space.index

              // Hyprspace's palette in this theme's colours: the workspace you
              // are on sits lighter than the rest, and the one a drag is about
              // to land on is the one picked out.
              //
              // Every box is outlined, which Hyprspace's defaults do not do --
              // its inactive border is transparent. It can afford that because
              // its boxes sit on the live desktop and their 50% black reads as
              // a shape. These sit on the strip's own dark band, where an
              // unoutlined empty workspace was invisible, and an invisible box
              // is nothing to aim a drag at.
              Rectangle {
                anchors.fill: parent
                radius: Style.cornerRadius
                color: space.current ? Util.alpha(Color.foreground, 0.08)
                  : Util.alpha(Color.background, 0.5)
                border.width: Math.max(1, Style.space(space.wanted ? 2 : 1))
                border.color: space.wanted ? Color.accent
                  : space.current ? Style.selectedBorderColor
                  : Style.normalBorderColor
              }

              // Which workspace this is. Hyprspace draws no label: it renders
              // the wallpaper and the bar into every box, so even an empty one
              // has something to tell it apart by. Nothing here can capture
              // another layer surface, so without the number a row of empty
              // workspaces is a row of identical blanks.
              Text {
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.margins: Style.space(6)
                text: space.modelData.id
                color: space.current ? Color.foreground : Color.muted
                font.pixelSize: Style.fontPx(1.2)
                font.family: Style.fontFamily
              }

              Item {
                anchors.fill: parent
                // A window hanging off the edge of its miniature must not spill
                // into the workspace next to it.
                clip: true

                // Beneath the windows, so a click on one of them is the
                // window's and a click on the space around them is the
                // workspace's. Inside this clip rather than beside it: as a
                // sibling declared under the clipping item it received no
                // pointer events whatsoever -- not a press, not even a hover --
                // including over an empty workspace where the clip holds
                // nothing at all. A HoverHandler on the very same box did fire
                // throughout, which is what separated "the box is not being
                // hit" from "the MouseArea is not being reached".
                MouseArea {
                  anchors.fill: parent
                  hoverEnabled: true

                  property double pressedAt: 0

                  onPressed: pressedAt = Date.now()
                  onReleased: {
                    if (panel.holding !== null) return
                    if (Date.now() - pressedAt >= root.clickMillis) return
                    root.switchTo(space.modelData.id)
                  }
                }

                Repeater {
                  model: space.modelData.windows

                  Item {
                    id: tile

                    required property var modelData

                    x: tile.modelData.rect.x
                    y: tile.modelData.rect.y
                    width: tile.modelData.rect.width
                    height: tile.modelData.rect.height
                    z: tile.modelData.depth

                    ScreencopyView {
                      anchors.fill: parent
                      captureSource: panel.visible ? tile.modelData.toplevel.wayland : null
                      live: true
                      paintCursor: false

                      onHasContentChanged: {
                        if (!hasContent || !tile.modelData.counted) return
                        panel.warm++
                        if (panel.warm < panel.captures) return
                        panel.ready = true
                        root.warmed()
                      }
                    }

                  }
                }
              }
            }
          }

        }
      }

      // The expose: this workspace's windows pulled apart until none covers
      // another. The strip cannot do this -- it draws every window where it
      // really sits, and on an untiled workspace that is a pile, which
      // photographs as one window and tells you exactly what the desktop
      // already showed. Hyprspace has no answer for it either.
      //
      // Each window flies from where it actually sits to its slot, so at
      // progress 0 the spread lines up pixel for pixel with the desktop behind.
      Item {
        id: expose

        anchors.fill: parent

        Repeater {
          model: panel.spread

          // Built at the size it rests at, then moved and scaled into place.
          // Both boxes carry the same window aspect, so a uniform scale is the
          // exact interpolation between them -- and binding width and height to
          // the swipe instead would relayout, and restart the capture, every
          // frame of the gesture.
          Item {
            id: flown

            required property var modelData

            width: flown.modelData.target.width
            height: flown.modelData.target.height
            transformOrigin: Item.TopLeft
            z: flown.modelData.toplevel === root.raised ? 1 : 0
            opacity: panel.holding === flown.modelData.toplevel ? root.dragAlpha : 1
            x: Model.lerp(flown.modelData.actual.x, flown.modelData.target.x, root.slide)
            y: Model.lerp(flown.modelData.actual.y, flown.modelData.target.y, root.slide)
            scale: Model.lerp(flown.modelData.actual.width / flown.modelData.target.width,
              1, root.slide)

            ScreencopyView {
              anchors.fill: parent
              captureSource: panel.visible ? flown.modelData.toplevel.wayland : null
              live: true
              paintCursor: false

              onHasContentChanged: {
                if (!hasContent || !flown.modelData.counted) return
                panel.warm++
                if (panel.warm < panel.captures) return
                panel.ready = true
                root.warmed()
              }
            }

            // Says which window a click is about to land on.
            Rectangle {
              anchors.fill: parent
              color: "transparent"
              radius: Math.max(0, Style.cornerRadius - Style.space(4))
              border.width: Math.max(1, Style.space(2))
              border.color: chooser.containsMouse ? Style.hoverBorderColor : "transparent"
            }

            MouseArea {
              id: chooser

              anchors.fill: parent
              hoverEnabled: true
              cursorShape: panel.holding === flown.modelData.toplevel
                ? Qt.ClosedHandCursor
                : Qt.PointingHandCursor

              property point origin

              onPressed: function (mouse) { chooser.origin = Qt.point(mouse.x, mouse.y) }

              onPositionChanged: function (mouse) {
                if (!chooser.pressed) return
                // A press only becomes a drag once it has travelled: without
                // this every click would pick the window up and put it straight
                // back down where it came from.
                var travelled = Math.abs(mouse.x - chooser.origin.x)
                  + Math.abs(mouse.y - chooser.origin.y)
                if (panel.holding === null && travelled < Style.space(8)) return

                panel.holding = flown.modelData.toplevel
                // Two coordinate spaces, because the two ends of the drag live
                // in different ones: the ghost follows the cursor across the
                // whole panel, while the workspace it would land on is found
                // inside the strip, which is panned and slid independently.
                var onPanel = chooser.mapToItem(carried.parent, mouse.x, mouse.y)
                // Sized from this tile, not from `carried`, whose own width is
                // still whatever the last drag left it -- 0 on the first one.
                var tall = panel.ghostHeight
                var wide = tall * (flown.width / flown.height)
                panel.ghost = Qt.rect(onPanel.x - wide / 2, onPanel.y - tall / 2, wide, tall)
                var inStrip = chooser.mapToItem(panned, mouse.x, mouse.y)
                panel.dropTarget = Model.boxAt(panel.boxes, inStrip.x, inStrip.y)
              }

              onReleased: {
                if (panel.holding === null) {
                  root.choose(flown.modelData.toplevel)
                  return
                }
                var onto = panel.dropTarget
                var carriedWindow = panel.holding
                panel.holding = null
                panel.dropTarget = -1
                if (onto < 0) return
                // Dropping a window back where it already lives is a no-op, not
                // a move: the compositor would re-tile the workspace for nothing.
                if (panel.slots[onto].workspace === panel.hyprMonitor.activeWorkspace) return
                panel.moveWindow(carriedWindow, panel.slots[onto].id)
              }

              onCanceled: {
                panel.holding = null
                panel.dropTarget = -1
              }
            }
          }
        }
      }

      // The window being carried, over everything and in the panel's own
      // coordinates: a drag starts in the spread at the bottom of the screen
      // and ends on a workspace at the top, crossing two clipping containers
      // on the way, so it cannot live inside either of them.
      Item {
        id: carried

        visible: panel.holding !== null
        x: panel.ghost.x
        y: panel.ghost.y
        width: panel.ghost.width
        height: panel.ghost.height
        opacity: 0.9

        ScreencopyView {
          anchors.fill: parent
          captureSource: panel.holding ? panel.holding.wayland : null
          live: true
          paintCursor: false
        }
      }
    }
  }
}
