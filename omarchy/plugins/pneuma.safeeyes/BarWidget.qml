import QtQuick
import qs.Commons
import qs.Ui

// A pause/resume toggle for the eye-break engine that lives visually inside
// the omarchy.indicators cluster: place it directly beside that widget in
// the bar layout. Always visible — a dimmed eye glyph while breaks run,
// a full-strength eye-off glyph while breaks are paused.
BarWidget {
  id: root
  moduleName: "pneuma.safeeyes"

  // serviceFor() is a function call, not a property, so a binding on it would
  // never re-evaluate once the shell finishes constructing the service.
  // Resolve by identity and retry until it exists (mirrors pneuma.pomodoro).
  property var eyes: null

  function resolveService() {
    var found = bar && bar.shell && typeof bar.shell.serviceFor === "function"
      ? bar.shell.serviceFor(root.moduleName)
      : null
    if (found && found !== eyes) eyes = found
  }

  onBarChanged: resolveService()
  Component.onCompleted: resolveService()

  Timer {
    interval: 400
    repeat: true
    running: root.eyes === null
    onTriggered: root.resolveService()
  }

  readonly property bool paused: eyes ? eyes.enabled !== true : false

  implicitWidth: vertical ? barSize : indicator.implicitWidth
  implicitHeight: vertical ? indicator.implicitHeight : barSize

  // Stands in for the Indicators module so BarIndicator's shared reveal
  // logic works outside it; always revealing keeps the running-state glyph
  // permanently visible (dimmed) instead of hover-peeked.
  QtObject {
    id: revealShim
    readonly property bool revealInactiveIndicators: true
  }

  BarIndicator {
    id: indicator
    anchors.centerIn: parent
    bar: root.bar
    active: root.paused
    indicatorHost: revealShim
    activeText: "󰈉"
    inactiveText: "󰈈"
    activeTooltipText: "Resume Eye Breaks"
    inactiveTooltipText: "Pause Eye Breaks"

    onPressed: function () {
      if (!root.eyes) return
      if (root.eyes.enabled) root.eyes.disableFor(0)
      else root.eyes.enable()
    }
  }
}
