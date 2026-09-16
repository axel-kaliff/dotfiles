import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
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

  // Hyprspace's own defaults (src/main.cpp): a 250px strip of miniatures with
  // 12px between them, scaled here the way every other length in the shell is.
  readonly property int panelHeight: Style.space(250)
  readonly property int workspaceMargin: Style.space(12)
  // Hyprspace's dragAlpha: what a window fades to where it used to be, so the
  // one under the cursor reads as the one being placed.
  readonly property real dragAlpha: 0.2
  // How far the spread below the strip insets from the screen edge.
  readonly property int exposeMargin: Style.space(56)
  // Hyprspace's click-to-exit timeout, and only that: a press and release
  // further apart than this was a drag that ended over nothing, not a click
  // meaning "close". It does not gate switching workspace -- Hyprspace's own
  // switch has no timing condition, and borrowing this one for it swallowed
  // every click held longer than 200ms.
  readonly property int clickMillis: 200

  // The gesture's own account of things: 0 is the bare desktop, 1 the settled
  // overview, and a live swipe carries it between.
  property real progress: 0
  property bool opened: false
  property string dragging: ""  // "up", "down", or "" when no gesture is live

  // What is actually drawn, on the same scale. Under a finger it runs ahead
  // of `progress` (see `drag`); let go, `settling` carries it home. Every
  // visual hangs off this one value.
  property real shown: 0

  // Raising the panel is the slow half of opening the overview: a fresh layer
  // surface costs a configure round-trip, a scene graph, and a screencopy
  // session per window. Armed means the panel is up and holding at shown 0,
  // where the strip is still off the top of the screen and there is nothing to
  // see. The cost is paid there, before anything moves.
  property bool armed: false

  // The desktop's own motion (hypr/looknfeel.lua): anything arriving rides
  // appleSpring, anything leaving takes appleExit, a short accelerating
  // bezier. The spring is solved in OverviewModel.js and handed to Qt as a
  // spline, so the overview opens with the shape and pace of a window
  // appearing. Leaving is slower than a window's 75ms: the thumbnails cross
  // the whole screen on the way back, and at 75ms that is four frames.
  readonly property var springCurve: Model.springCurve(520, 38, 1, 0.3, 10)
  readonly property var exitCurve: [0.3, 0, 0.8, 0.15, 1, 1]
  readonly property int openDuration: 300
  readonly property int closeDuration: 180

  NumberAnimation {
    id: settling

    target: root
    property: "shown"
    easing.type: Easing.BezierSpline
    // Only a settle that ran to its end takes the panel down; one cut short
    // by a new swipe has handed `shown` to the fingers.
    onFinished: if (!root.opened) root.rest()
  }

  function settle(open) {
    root.dragging = ""
    root.opened = open
    root.progress = open ? 1 : 0
    settling.stop()
    settling.to = open ? 1 : 0
    settling.duration = open ? root.openDuration : root.closeDuration
    settling.easing.bezierCurve = open ? root.springCurve : root.exitCurve
    settling.restart()
  }

  // The desktop's wallpaper, drawn frosted behind the overview the way GNOME
  // and Mission Control both do: the real windows fade out beneath their
  // thumbnails as those fly into place, and what is left is a place of its
  // own rather than a wash over the desktop. Resolved the way the background
  // plugin resolves it, once at start and again each time the overview is
  // raised, since the wallpaper can change while the shell runs.
  property string wallpaper: ""

  Process {
    id: wallpaperLookup

    command: ["readlink", "-f", Quickshell.env("HOME") + "/.local/state/omarchy/current/background"]
    stdout: StdioCollector {
      onStreamFinished: root.wallpaper = String(text).trim()
    }
  }

  Component.onCompleted: wallpaperLookup.running = true

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

  onArmedChanged: {
    if (!root.armed) {
      deadline.stop()
      return
    }
    deadline.restart()
    wallpaperLookup.running = true
  }

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

  function drag(distance) {
    if (root.dragging === "") return
    var from = root.opened ? 1 : 0
    var direction = root.dragging === "up" ? 1 : -1
    root.progress = Model.clamp(from + direction * distance / root.travelToOpen, 0, 1)
    // Ahead of the swipe rather than in step with it: eased this way the strip
    // is already readable around the halfway mark, where a linear slide still
    // has it mostly off screen at exactly the moment you are looking.
    root.shown = 1 - Math.pow(1 - root.progress, 3)
  }

  function handle(message) {
    if (message === "start:up") {
      if (root.opened) return
      // A close still running is the fingers' now.
      settling.stop()
      root.dragging = "up"
      // Fingers down, nothing carried yet: the cheapest moment there is to pay
      // for the panel, and the travel that follows covers what is left of it.
      root.armed = true
    } else if (message === "start:down") {
      if (!root.opened) return
      settling.stop()
      root.dragging = "down"
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
      // Which slot is the active workspace, the one the expose spreads out
      // below. A drop anywhere in that spread lands here (see `carry`).
      property int activeSlot: -1

      // How far the strip is panned and how far it may be. A transform on the
      // whole strip, never a relayout, for the same reason.
      property real pan: 0
      property real panLimit: 0

      // The wheel glides the strip rather than stepping it. Not while the
      // overview is being laid out: centring on the way in is a placement,
      // not a move.
      Behavior on pan {
        enabled: root.opened
        NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
      }

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
        var activeSlot = -1
        for (var slot = 0; slot < ids.length; slot++) {
          var workspace = null
          for (var w = 0; w < mine.length; w++) if (mine[w].id === ids[slot]) workspace = mine[w]
          if (active && ids[slot] === active.id) activeSlot = slot

          var box = laid.boxes[slot]
          var onScreen = box.x + panel.pan < panel.width && box.x + box.width + panel.pan > 0
          var windows = panel.windowsIn(workspace, box, onScreen)
          // Each window decides for itself, so a box that is on screen but
          // holds one window scrolled off the monitor contributes only the
          // thumbnails that will actually arrive.
          for (var c = 0; c < windows.length; c++) if (windows[c].counted) total++
          built.push({ id: ids[slot], workspace: workspace, box: box, windows: windows })
        }
        panel.activeSlot = activeSlot

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

      // Carrying a window. Both places one can be picked up run through here:
      // the spread below, and the miniatures inside the workspace thumbnails.
      // `area` supplies the press origin and the window, so the only thing that
      // differs between the two is where the press came from.
      function carry(area, mouse) {
        var travelled = Math.abs(mouse.x - area.origin.x) + Math.abs(mouse.y - area.origin.y)
        // A press only becomes a drag once it has travelled: without this every
        // click would pick the window up and put it straight back down.
        if (panel.holding === null && travelled < Style.space(8)) return

        panel.holding = area.dragged
        // Two coordinate spaces, because the two ends of a drag live in
        // different ones: the ghost follows the cursor across the whole panel,
        // while the workspace it would land on is found inside the strip, which
        // is panned and slid independently of everything else.
        var tall = panel.ghostHeight
        var wide = tall * (area.width / area.height)
        var onPanel = area.mapToItem(carried.parent, mouse.x, mouse.y)
        panel.ghost = Qt.rect(onPanel.x - wide / 2, onPanel.y - tall / 2, wide, tall)

        var inStrip = area.mapToItem(panned, mouse.x, mouse.y)
        // A drop below the strip lands on the active workspace, whose windows
        // fill the spread there: the big centre area is the obvious place to
        // aim "put this on the workspace I'm in", and hit-testing only the
        // strip left it inert -- a window dragged into it went nowhere.
        panel.dropTarget = Model.dropSlot(panel.boxes, inStrip.x, inStrip.y,
          onPanel.y, root.panelHeight, panel.activeSlot)
      }

      function release() {
        panel.holding = null
        panel.dropTarget = -1
      }

      // `home` is the workspace the window is on now: a drop back onto it is a
      // no-op, not a move that would re-tile the workspace for nothing.
      function drop(home) {
        var onto = panel.dropTarget
        var carriedWindow = panel.holding
        panel.release()
        if (onto < 0 || carriedWindow === null) return
        if (panel.slots[onto].workspace === home) return
        panel.moveWindow(carriedWindow, panel.slots[onto].id)
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
      mask: root.shown > 0 ? null : untouchable
      WlrLayershell.namespace: "pneuma-overview"
      WlrLayershell.layer: WlrLayer.Overlay
      // Taken only once the overview has settled open: a swipe the user
      // abandons must not have stolen the keyboard from what they were typing.
      //
      // Emphatically not given up again for the length of a drag, which is what
      // it used to do so that a move dispatch would not be swallowed. Two
      // measurements killed that: reconfiguring the layer surface mid-gesture
      // drops the pointer grab, so a drag delivered exactly one motion event
      // and then never a release; and a move dispatch is not swallowed anyway,
      // having been watched moving a window between workspaces with this layer
      // holding the keyboard exclusively. Only `hl.dsp.focus` needs the
      // handover, and that one closes the overview first regardless.
      WlrLayershell.keyboardFocus: root.opened && root.dragging === ""
        ? WlrKeyboardFocus.Exclusive
        : WlrKeyboardFocus.None
      exclusionMode: ExclusionMode.Ignore

      // The frosted wallpaper. Drawn at a quarter of the screen and scaled
      // back up: a blur this wide hides the difference, and it keeps the
      // texture and the blur pass to a sixteenth of the cost. The frame
      // reaches `bleed` past every edge so the blur has pixels to sample at
      // the screen's border instead of fading to nothing there.
      Item {
        id: frost

        readonly property int shrink: 4
        readonly property int bleed: 16

        x: -frost.bleed * frost.shrink
        y: -frost.bleed * frost.shrink
        width: Math.ceil(panel.width / frost.shrink) + frost.bleed * 2
        height: Math.ceil(panel.height / frost.shrink) + frost.bleed * 2
        scale: frost.shrink
        transformOrigin: Item.TopLeft
        opacity: root.shown

        Image {
          anchors.fill: parent
          source: root.wallpaper ? Util.fileUrl(root.wallpaper) : ""
          sourceSize.width: frost.width
          fillMode: Image.PreserveAspectCrop
          asynchronous: true
          layer.enabled: true
          layer.smooth: true
          layer.effect: MultiEffect {
            autoPaddingEnabled: false
            blurEnabled: true
            blur: 1
            blurMax: 16
          }
        }
      }

      // The menu's scrim over the frost, so the overview is dimmed the way
      // every other modal surface in the shell is.
      Rectangle {
        anchors.fill: parent
        color: Color.menu.scrim
        opacity: root.shown
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
        y: Model.lerp(-root.panelHeight, 0, root.shown)

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
              // The empty slot at the end: a place a window could go, not a
              // workspace that exists. By position, not by having no
              // workspace behind it: a gap in the numbering has none either,
              // and it is a workspace all the same.
              readonly property bool fresh: space.index === panel.slots.length - 1
              // Passive, so hovering a miniature inside still counts as
              // hovering the workspace it is on.
              readonly property bool hovered: over.hovered && panel.holding === null

              HoverHandler { id: over }

              // Swells a little under a carried window, the way GNOME's
              // thumbnails do, so the one about to take it is unmistakable.
              scale: space.wanted ? 1.04 : 1

              Behavior on scale {
                NumberAnimation { duration: 140; easing.type: Easing.OutCubic }
              }

              // The switcher's shadow, so the two read as the same material.
              // Not under the empty slot: that is an outline of a place, and
              // weight under it would make it a card like the others.
              RectangularShadow {
                anchors.fill: parent
                visible: !space.fresh
                radius: face.radius
                blur: Style.space(28)
                offset.y: Style.space(6)
                color: Qt.rgba(0, 0, 0, 0.3)
              }

              // Hyprspace's palette in the shell's own tokens: the workspace
              // you are on wears the bar's focused-workspace pill, the one a
              // drag is about to land on is picked out in the accent, and the
              // rest sit as dark glass on the frost.
              //
              // Every box is outlined, which Hyprspace's defaults do not do --
              // its inactive border is transparent. It can afford that because
              // its boxes sit on the live desktop and their 50% black reads as
              // a shape. On the frost an unoutlined empty workspace was
              // invisible, and an invisible box is nothing to aim a drag at.
              ClippingRectangle {
                id: face

                anchors.fill: parent
                radius: Style.cornerRadius
                contentUnderBorder: true
                color: space.wanted ? Style.selectedAccentFill
                  : space.current ? Style.selectedFill
                  : space.hovered ? Style.hoverFill
                  : Util.alpha(Color.background, space.fresh ? 0.25 : 0.45)
                border.width: Math.max(1, Style.space(space.wanted ? 2 : 1))
                border.color: space.wanted ? Color.accent
                  : space.hovered ? Style.hoverBorderColor
                  : Util.alpha(Color.foreground, space.current ? 0.35 : 0.12)

                Behavior on color {
                  ColorAnimation { duration: 140; easing.type: Easing.OutCubic }
                }
                Behavior on border.color {
                  ColorAnimation { duration: 140; easing.type: Easing.OutCubic }
                }

                // Beneath the windows, so a click on one of them is the
                // window's and a click on the space around them is the
                // workspace's. Inside the clip rather than beside it: as a
                // sibling declared under the clipping item it received no
                // pointer events whatsoever -- not a press, not even a hover
                // -- including over an empty workspace where the clip holds
                // nothing at all. A HoverHandler on the very same box did fire
                // throughout, which is what separated "the box is not being
                // hit" from "the MouseArea is not being reached".
                MouseArea {
                  anchors.fill: parent

                  // No timing rule here, deliberately. Hyprspace's 200ms
                  // press-to-release window is for click-to-exit only -- its
                  // own comment says so, and `couldExit` gates just that branch
                  // -- while its workspace switch has no timing condition at
                  // all. Applied here it swallowed every click held longer than
                  // 200ms, which is most deliberate ones: measured, a 600ms
                  // click on workspace 6 left the desktop on workspace 2. The
                  // drag it needs to be told apart from is already excluded by
                  // `holding`, and a drag's release goes to the window that
                  // started it, never here.
                  onReleased: {
                    if (panel.holding !== null) return
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
                    opacity: panel.holding === tile.modelData.toplevel ? root.dragAlpha : 1

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

                    // Says which window a drag is about to lift.
                    Rectangle {
                      anchors.fill: parent
                      color: "transparent"
                      border.width: grip.containsMouse ? Math.max(1, Style.space(1)) : 0
                      border.color: Style.hoverBorderColor
                    }

                    // A window can be picked up from its miniature too, not
                    // only from the spread below, so a window already on
                    // another workspace can be moved without going there first.
                    // A press that never travels falls through to what the
                    // workspace box beneath would have done: take me there.
                    MouseArea {
                      id: grip

                      readonly property var dragged: tile.modelData.toplevel
                      readonly property var home: space.modelData.workspace
                      property point origin

                      anchors.fill: parent
                      hoverEnabled: true
                      cursorShape: panel.holding === grip.dragged
                        ? Qt.ClosedHandCursor
                        : Qt.PointingHandCursor

                      onPressed: function (mouse) { grip.origin = Qt.point(mouse.x, mouse.y) }
                      onPositionChanged: function (mouse) {
                        if (grip.pressed) panel.carry(grip, mouse)
                      }
                      onReleased: {
                        if (panel.holding === null) root.switchTo(space.modelData.id)
                        else panel.drop(grip.home)
                      }
                      onCanceled: panel.release()
                    }
                  }
                }
              }

              // Which workspace this is. Hyprspace draws no label: it renders
              // the wallpaper and the bar into every box, so even an empty one
              // has something to tell it apart by. Nothing here can capture
              // another layer surface, so without the number a row of empty
              // workspaces is a row of identical blanks.
              Rectangle {
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.margins: Style.space(8)
                width: label.implicitWidth + Style.space(12)
                height: label.implicitHeight + Style.space(4)
                radius: height / 2
                color: Util.alpha(Color.background, 0.7)

                Text {
                  id: label

                  anchors.centerIn: parent
                  text: space.modelData.id
                  color: space.current ? Color.foreground : Color.muted
                  font.family: Style.font.family
                  font.pixelSize: Style.font.caption
                }
              }

              Text {
                anchors.centerIn: parent
                visible: space.fresh
                text: "+"
                color: Color.muted
                font.family: Style.font.family
                font.pixelSize: Style.font.displayLarge
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
      // shown 0 the spread lines up pixel for pixel with the desktop behind.
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

            readonly property var wayland: flown.modelData.toplevel.wayland
            readonly property string iconSource: {
              var entry = DesktopEntries.heuristicLookup(String(flown.wayland.appId))
              var name = entry && entry.icon ? entry.icon : ""
              return name ? Quickshell.iconPath(name, true) : ""
            }

            width: flown.modelData.target.width
            height: flown.modelData.target.height
            transformOrigin: Item.TopLeft
            z: flown.modelData.toplevel === root.raised ? 1 : 0
            opacity: panel.holding === flown.modelData.toplevel ? root.dragAlpha : 1
            x: Model.lerp(flown.modelData.actual.x, flown.modelData.target.x, root.shown)
            y: Model.lerp(flown.modelData.actual.y, flown.modelData.target.y, root.shown)
            scale: Model.lerp(flown.modelData.actual.width / flown.modelData.target.width,
              1, root.shown)

            // The desktop's window shadow, at the depth a lifted window gets.
            // Faded in with the spread: at rest the tile sits on the real
            // window, which casts its own.
            RectangularShadow {
              anchors.fill: parent
              radius: frame.radius
              blur: Style.space(32)
              offset.y: Style.space(10)
              color: Qt.rgba(0, 0, 0, 0.45)
              opacity: root.shown
            }

            ClippingRectangle {
              id: frame

              anchors.fill: parent
              radius: Style.cornerRadius
              contentUnderBorder: true
              // Shows through until the capture has a frame.
              color: Util.alpha(Color.background, 0.6)
              border.width: Math.max(1, Style.space(1))
              border.color: chooser.containsMouse ? Style.hoverBorderColor
                : Util.alpha(Color.foreground, 0.12)

              Behavior on border.color {
                ColorAnimation { duration: 140; easing.type: Easing.OutCubic }
              }

              ScreencopyView {
                anchors.fill: parent
                captureSource: panel.visible ? flown.wayland : null
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

              MouseArea {
                id: chooser

                // A window in the spread lives on the workspace being shown.
                readonly property var dragged: flown.modelData.toplevel
                readonly property var home: panel.hyprMonitor
                  ? panel.hyprMonitor.activeWorkspace : null
                property point origin

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: panel.holding === chooser.dragged
                  ? Qt.ClosedHandCursor
                  : Qt.PointingHandCursor

                onPressed: function (mouse) { chooser.origin = Qt.point(mouse.x, mouse.y) }
                onPositionChanged: function (mouse) {
                  if (chooser.pressed) panel.carry(chooser, mouse)
                }
                onReleased: {
                  // A press that never travelled is a click, and a click on a
                  // window means that window.
                  if (panel.holding === null) root.choose(chooser.dragged)
                  else panel.drop(chooser.home)
                }
                onCanceled: panel.release()
              }
            }

            // Names the window under the pointer, the way GNOME's overview
            // does: a thumbnail of a terminal looks like every other terminal.
            Rectangle {
              id: caption

              anchors.horizontalCenter: parent.horizontalCenter
              anchors.bottom: parent.bottom
              anchors.bottomMargin: Style.space(12)
              width: named.implicitWidth + Style.space(20)
              height: named.implicitHeight + Style.space(12)
              radius: height / 2
              color: Util.alpha(Color.background, 0.75)
              border.width: Math.max(1, Style.space(1))
              border.color: Util.alpha(Color.foreground, 0.12)
              opacity: chooser.containsMouse && panel.holding === null ? 1 : 0

              Behavior on opacity {
                NumberAnimation { duration: 140; easing.type: Easing.OutCubic }
              }

              Row {
                id: named

                anchors.centerIn: parent
                spacing: Style.space(6)

                IconImage {
                  visible: flown.iconSource !== ""
                  source: flown.iconSource
                  implicitSize: Style.space(16)
                  anchors.verticalCenter: parent.verticalCenter
                }

                Text {
                  anchors.verticalCenter: parent.verticalCenter
                  width: Math.min(implicitWidth, flown.width - Style.space(72))
                  text: String(flown.wayland.title)
                  color: Color.foreground
                  font.family: Style.font.family
                  font.pixelSize: Style.font.bodySmall
                  elide: Text.ElideRight
                  maximumLineCount: 1
                }
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

        readonly property bool lifted: panel.holding !== null

        visible: carried.lifted
        x: panel.ghost.x
        y: panel.ghost.y
        width: panel.ghost.width
        height: panel.ghost.height
        // Picked up rather than switched on: it grows into the hand. Only on
        // the way up -- once dropped, its capture is already gone, and a
        // fade-out would be of an empty frame.
        opacity: carried.lifted ? 0.9 : 0
        scale: carried.lifted ? 1 : 0.85

        Behavior on opacity {
          enabled: carried.lifted
          NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
        }
        Behavior on scale {
          enabled: carried.lifted
          NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
        }

        RectangularShadow {
          anchors.fill: parent
          radius: held.radius
          blur: Style.space(32)
          offset.y: Style.space(10)
          color: Qt.rgba(0, 0, 0, 0.45)
        }

        ClippingRectangle {
          id: held

          anchors.fill: parent
          radius: Style.cornerRadius
          color: Util.alpha(Color.background, 0.6)

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
}
