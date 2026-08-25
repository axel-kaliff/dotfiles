import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.Commons
import "Model.js" as Model

// Eye-break engine ported from soramanew/safeeyes (the caelestia desktop's
// break app): a short look-away break on a fixed cadence, every fourth break
// stretched into a long stand-up break, shown as a full-screen overlay on
// every monitor. Declared a `service` kind so exactly one engine runs per
// session; the overlay windows are owned by the engine itself rather than a
// per-monitor bar surface.
//
// Deadlines are wall-clock timestamps rather than decremented counters, so a
// suspended laptop or a slow tick resolves to the same remaining time
// (mirrors pneuma.pomodoro). Breaks are advisory, never enforced: Escape or
// the skip pill dismisses one, and a fullscreen focused window (video, game)
// silently postpones the cadence by a full interval.
Item {
  id: root

  // Injected by the shell's service loader.
  property var shell: null
  property var manifest: null
  property string omarchyPath: ""

  // Cadence, matching the soramanew/safeeyes defaults: with a 15 minute
  // interval and every 4th break long, the long break lands once an hour.
  property int intervalMinutes: 15
  property int prewarnSeconds: 10
  property int shortBreakSeconds: 15
  property int longBreakSeconds: 60
  property int breaksPerLong: 4

  property bool enabled: true
  property string phase: "waiting"   // waiting | prewarn | break
  property string breakType: "short"
  property string prompt: ""
  property int breakCount: 0
  property double nextBreakAt: 0     // epoch ms; authoritative while waiting
  property double phaseEndsAt: 0     // epoch ms; end of a running prewarn/break
  property double disabledUntil: 0   // epoch ms; informational, 0 = no timed snooze
  property double nowMs: Date.now()

  readonly property bool breakActive: phase === "break"
  readonly property int breakLengthSeconds: breakType === "long" ? longBreakSeconds : shortBreakSeconds
  readonly property int secondsLeft: Math.max(0, Math.ceil((phaseEndsAt - nowMs) / 1000))
  readonly property real breakProgress: breakActive
    ? Math.max(0, Math.min(1, (phaseEndsAt - nowMs) / (breakLengthSeconds * 1000)))
    : 0

  readonly property bool fullscreenFocused: ToplevelManager.activeToplevel
    ? ToplevelManager.activeToplevel.fullscreen === true
    : false

  readonly property string notifyBin: (omarchyPath !== "" ? omarchyPath + "/bin/" : "") + "omarchy-notification-send"
  readonly property string chimeSound: "/usr/share/sounds/freedesktop/stereo/complete.oga"

  // ------------------------------------------------------------- lifecycle

  function scheduleNext() {
    nowMs = Date.now()
    phase = "waiting"
    nextBreakAt = nowMs + intervalMinutes * 60000
  }

  function beginPrewarn() {
    breakType = Model.breakTypeFor(breakCount + 1, breaksPerLong)
    phase = "prewarn"
    phaseEndsAt = nowMs + prewarnSeconds * 1000
    Quickshell.execDetached([notifyBin, "-g", "󰈈", "Safe Eyes",
      (breakType === "long" ? "Long" : "Short") + " break in " + prewarnSeconds + " seconds"])
  }

  function startBreak(kind) {
    breakType = kind
    breakCount += 1
    prompt = Model.pickPrompt(kind, Math.random())
    phase = "break"
    phaseEndsAt = nowMs + breakLengthSeconds * 1000
  }

  function endBreak(chime) {
    // Fire-and-forget: a missing player costs a silent break end, never a
    // stuck overlay.
    if (chime) Quickshell.execDetached(["pw-play", chimeSound])
    scheduleNext()
  }

  function dismissBreak() {
    if (phase !== "waiting") scheduleNext()
  }

  function triggerBreak(kind) {
    if (!enabled || phase !== "waiting") return
    nowMs = Date.now()
    startBreak(kind === "long" ? "long" : "short")
  }

  function enable() {
    resumeTimer.stop()
    disabledUntil = 0
    enabled = true
    scheduleNext()
  }

  // minutes <= 0 disables until an explicit enable. The timed resume rides a
  // monotonic timer, so sleeping through a snooze extends it — acceptable
  // for a state that is short-lived by definition.
  function disableFor(minutes) {
    phase = "waiting"
    enabled = false
    if (minutes > 0) {
      disabledUntil = Date.now() + minutes * 60000
      resumeTimer.interval = minutes * 60000
      resumeTimer.restart()
    } else {
      disabledUntil = 0
      resumeTimer.stop()
    }
  }

  // --------------------------------------------------------------- ticking

  function tick() {
    nowMs = Date.now()

    if (phase === "waiting") {
      if (nowMs < nextBreakAt) return
      if (fullscreenFocused) {
        nextBreakAt = nowMs + intervalMinutes * 60000
        return
      }
      beginPrewarn()
      return
    }

    if (nowMs < phaseEndsAt) return
    if (phase === "prewarn") {
      startBreak(breakType)
      return
    }
    // Chime only when the break actually ran down on screen; a deadline
    // overshot by more than a beat means the machine slept through it.
    endBreak(nowMs - phaseEndsAt < 5000)
  }

  // Coarse while waiting, fine while a countdown is on screen.
  Timer {
    interval: root.phase === "waiting" ? 5000 : 250
    repeat: true
    running: root.enabled
    onTriggered: root.tick()
  }

  Timer {
    id: resumeTimer
    repeat: false
    onTriggered: root.enable()
  }

  Component.onCompleted: scheduleNext()

  // ------------------------------------------------------------------ IPC

  // Keybinding / CLI control:
  //   omarchy-shell safeeyes status
  //   omarchy-shell safeeyes takeBreak long
  //   omarchy-shell safeeyes disable 60
  IpcHandler {
    target: "safeeyes"

    function enable(): string { root.enable(); return "ok" }
    function disable(minutes: string): string {
      root.disableFor(parseInt(minutes, 10) || 0)
      return "ok"
    }
    function skip(): string { root.dismissBreak(); return "ok" }
    function takeBreak(kind: string): string { root.triggerBreak(kind); return "ok" }
    function status(): string {
      return JSON.stringify({
        enabled: root.enabled,
        phase: root.phase,
        breakType: root.breakType,
        secondsLeft: root.secondsLeft,
        breakCount: root.breakCount,
        nextBreakAt: root.enabled && root.phase === "waiting" ? Model.formatClock(root.nextBreakAt) : "",
        disabledUntil: root.disabledUntil > 0 ? Model.formatClock(root.disabledUntil) : ""
      })
    }
  }

  // --------------------------------------------------------------- overlay

  Variants {
    model: Quickshell.screens

    PanelWindow {
      id: overlay

      required property var modelData

      // One scalar drives the whole entrance (caelestia's offsetScale
      // pattern): position and opacity animate together, overshooting in on
      // the MD3 expressive spatial curve and accelerating out on the
      // emphasized-accelerate curve. The window only exists on screen while
      // a break is active or still sliding away.
      screen: modelData
      visible: root.breakActive || content.offsetScale < 1
      anchors { top: true; bottom: true; left: true; right: true }
      color: "transparent"
      WlrLayershell.namespace: "pneuma-safeeyes"
      WlrLayershell.layer: WlrLayer.Overlay
      WlrLayershell.keyboardFocus: root.breakActive ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
      exclusionMode: ExclusionMode.Ignore

      Rectangle {
        anchors.fill: parent
        color: Color.background
        opacity: 0.92 * (1 - content.offsetScale)
      }

      // Swallow clicks so the desktop stays untouchable during a break;
      // dismissal is the pill or Escape, never a stray click.
      MouseArea {
        anchors.fill: parent
      }

      Item {
        id: content

        property real offsetScale: root.breakActive ? 0 : 1

        anchors.fill: parent
        opacity: 1 - offsetScale

        Behavior on offsetScale {
          NumberAnimation {
            duration: root.breakActive ? 250 : 125
            easing.type: Easing.BezierSpline
            easing.bezierCurve: root.breakActive
              ? [0.38, 1.21, 0.22, 1, 1, 1]
              : [0.3, 0, 0.8, 0.15, 1, 1]
          }
        }

        Column {
          anchors.horizontalCenter: parent.horizontalCenter
          anchors.verticalCenter: parent.verticalCenter
          anchors.verticalCenterOffset: Math.round(overlay.height * 0.05 * content.offsetScale)
          spacing: Style.space(28)

          Text {
            anchors.horizontalCenter: parent.horizontalCenter
            width: Math.round(overlay.width * 0.85)
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            text: root.prompt
            color: Color.foreground
            font.family: Style.font.family
            font.bold: true
            font.pixelSize: Math.round(Style.font.displayLarge * 1.5)
          }

          Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: String(root.secondsLeft)
            color: Color.foreground
            font.family: Style.font.family
            font.pixelSize: Style.font.displayLarge * 3
          }

          Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            width: Style.space(260)
            height: Style.space(4)
            radius: height / 2
            color: Util.alpha(Color.foreground, 0.25)

            Rectangle {
              width: parent.width * root.breakProgress
              height: parent.height
              radius: parent.radius
              color: Color.accent

              Behavior on width {
                NumberAnimation { duration: 250 }
              }
            }
          }

          Item { width: 1; height: Style.space(10) }

          Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            width: skipLabel.implicitWidth + Style.space(32)
            height: skipLabel.implicitHeight + Style.space(16)
            radius: height / 2
            color: Util.alpha(Color.foreground, skipArea.containsMouse ? 0.16 : 0.08)

            Text {
              id: skipLabel
              anchors.centerIn: parent
              text: "Skip · Esc"
              color: Color.foreground
              font.family: Style.font.family
              font.pixelSize: Style.font.body
            }

            MouseArea {
              id: skipArea
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: root.dismissBreak()
            }
          }
        }

        Item {
          id: keyCatcher
          anchors.fill: parent
          focus: true

          Keys.onPressed: function (event) {
            if (event.key === Qt.Key_Escape) {
              root.dismissBreak()
              event.accepted = true
            }
          }
        }
      }

      Connections {
        target: root
        function onBreakActiveChanged() {
          if (root.breakActive) Qt.callLater(function () { keyCatcher.forceActiveFocus() })
        }
      }
    }
  }
}
