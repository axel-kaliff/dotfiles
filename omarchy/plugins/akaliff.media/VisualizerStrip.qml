import QtQuick
import qs.Ui
import qs.Commons
import Lateralus.ProjectM

// The only file that touches the native Lateralus.ProjectM module (the
// projectM/Milkdrop engine baked into the lateralus image). BarWidget probes
// this component at startup and mounts it via Loader, so machines without the
// plugin keep the stock popup untouched.
BorderSurface {
  id: strip

  property QtObject bar: null
  property bool playing: false
  property alias presetDuration: view.presetDuration

  radius: Style.spacing.labelGap
  color: bar ? Style.normalFillFor(bar.foreground, Color.accent) : "transparent"
  borderSpec: bar ? Border.controlSpec("normal", bar.foreground, Color.accent) : Border.none()

  ProjectMView {
    id: view

    anchors.fill: parent
    // Same convention as the album-art tile: a 2px inset inside the small
    // radius instead of a masking pass. FBO content cannot paint outside the
    // item rect, so no clip is needed.
    anchors.margins: Style.space(2)

    // The idle animation on silence doesn't need full rate.
    fps: strip.playing ? 30 : 20

    opacity: 0
    Component.onCompleted: opacity = 1
    Behavior on opacity {
      NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
    }
  }

  MouseArea {
    anchors.fill: parent
    cursorShape: Qt.PointingHandCursor
    onClicked: view.nextPreset()
    onDoubleClicked: view.presetLocked = !view.presetLocked
  }
}
