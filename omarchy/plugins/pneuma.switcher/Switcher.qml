import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.Commons
import qs.Ui
import "SwitcherModel.js" as Model

// Alt-Tab the macOS way: hold Alt, tap Tab to walk the windows most recent
// first, let go of Alt to land on the highlighted one. Hyprland delivers
// ALT+TAB, ALT+SHIFT+TAB and the release of Alt as global shortcuts (see
// hypr/bindings.lua), so no key ever has to reach the overlay for it to work;
// it takes the keyboard while open only for Escape, Enter and the arrows.
Item {
  id: root

  property bool opened: false
  property int index: 0
  property var order: []          // Toplevel objects, most recent first
  property string screenName: ""  // the monitor the overlay opened on
  readonly property int maxCards: 7
  readonly property int firstCard: Model.firstVisible(index, order.length, maxCards)
  readonly property var visibleCards: order.slice(firstCard, firstCard + maxCards)

  function presentToplevels() { return ToplevelManager.toplevels.values }

  function reconcile() {
    order = Model.reconcile(order, presentToplevels())
    index = Model.wrap(index, order.length)
  }

  function noteActivated(toplevel) {
    if (!toplevel || opened) return
    order = Model.moveToFront(order, toplevel)
  }

  function step(delta) {
    reconcile()
    if (order.length === 0) return
    if (!opened) {
      screenName = Hyprland.focusedMonitor ? String(Hyprland.focusedMonitor.name) : ""
      index = Model.wrap(order.length > 1 ? delta : 0, order.length)
      opened = true
      return
    }
    index = Model.wrap(index + delta, order.length)
  }

  function commit() {
    if (!opened) return
    var target = order[index]
    opened = false
    if (!target) return
    target.activate()
    order = Model.moveToFront(order, target)
  }

  function cancel() { opened = false }

  function choose(position) {
    index = position
    commit()
  }

  Connections {
    target: ToplevelManager
    function onActiveToplevelChanged() { root.noteActivated(ToplevelManager.activeToplevel) }
  }

  Connections {
    target: ToplevelManager.toplevels
    function onValuesChanged() { root.reconcile() }
  }

  Component.onCompleted: {
    reconcile()
    noteActivated(ToplevelManager.activeToplevel)
  }

  GlobalShortcut {
    appid: "pneuma-switcher"
    name: "next"
    description: "Window switcher: next window"
    onPressed: root.step(1)
  }

  GlobalShortcut {
    appid: "pneuma-switcher"
    name: "prev"
    description: "Window switcher: previous window"
    onPressed: root.step(-1)
  }

  GlobalShortcut {
    appid: "pneuma-switcher"
    name: "commit"
    description: "Window switcher: land on the highlighted window"
    onPressed: root.commit()
  }

  IpcHandler {
    target: "pneuma.switcher"

    function next(): string { root.step(1); return "ok" }
    function prev(): string { root.step(-1); return "ok" }
    function commit(): string { root.commit(); return "ok" }
    function cancel(): string { root.cancel(); return "ok" }
    function state(): string {
      var active = ToplevelManager.activeToplevel
      return JSON.stringify({
        opened: root.opened,
        index: root.index,
        count: root.order.length,
        active: active ? String(active.title) : "",
        order: root.order.map(function (toplevel) { return String(toplevel.title) })
      })
    }
  }

  Variants {
    model: Quickshell.screens

    PanelWindow {
      id: panel

      required property var modelData

      screen: modelData
      visible: root.opened && (root.screenName === "" || root.screenName === String(modelData.name))
      anchors { top: true; bottom: true; left: true; right: true }
      color: "transparent"
      WlrLayershell.namespace: "pneuma-switcher"
      WlrLayershell.layer: WlrLayer.Overlay
      WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
      exclusionMode: ExclusionMode.Ignore

      // A click on the desktop around the strip cancels.
      MouseArea {
        anchors.fill: parent
        onClicked: root.cancel()
      }

      Item {
        anchors.fill: parent
        focus: true

        Keys.onPressed: function (event) {
          if (event.key === Qt.Key_Escape) root.cancel()
          else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) root.commit()
          else if (event.key === Qt.Key_Left) root.step(-1)
          else if (event.key === Qt.Key_Right) root.step(1)
          else return
          event.accepted = true
        }

        Keys.onReleased: function (event) {
          if (event.key !== Qt.Key_Alt) return
          root.commit()
          event.accepted = true
        }
      }

      // Same material as the OSD: the popup surface tokens on one soft drop
      // shadow, blurred by the pneuma-switcher layer rule in looknfeel.lua.
      RectangularShadow {
        anchors.fill: strip
        radius: strip.radius
        blur: Style.space(28)
        offset.y: Style.space(6)
        color: Qt.rgba(0, 0, 0, 0.3)
      }

      BorderSurface {
        id: strip

        readonly property int pad: Style.space(12)

        anchors.centerIn: parent
        width: row.implicitWidth + pad * 2 + borderLeft + borderRight
        height: row.implicitHeight + pad * 2 + borderTop + borderBottom
        radius: Style.cornerRadius
        color: Color.popups.background
        borderSpec: Border.surfaceSpec("popups", "border", Color.popups.border, Math.max(1, Style.space(2)))

        Row {
          id: row
          x: strip.borderLeft + strip.pad
          y: strip.borderTop + strip.pad
          spacing: Style.space(8)

          Repeater {
            model: root.visibleCards

            WindowCard {
              required property var modelData
              required property int index

              toplevel: modelData
              selected: root.firstCard + index === root.index
              capturing: panel.visible
              onChosen: root.choose(root.firstCard + index)
            }
          }
        }
      }
    }
  }
}
