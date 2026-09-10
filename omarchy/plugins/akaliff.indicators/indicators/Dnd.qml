import QtQuick
import qs.Commons
import qs.Ui

BarIndicator {
  id: root

  // firstPartyServiceFor() is the one shell lookup that skips
  // resolveEnabledId(), so it returns null once a clone provides the
  // notifications service. Resolve the id the way the other call paths do.
  readonly property var notificationService: {
    var shell = bar?.shell
    if (!shell || !shell.pluginRegistry) return null
    return shell.serviceFor(shell.pluginRegistry.resolveEnabledId("omarchy.notifications"))
  }
  readonly property bool dnd: notificationService ? notificationService.doNotDisturb : false

  active: dnd
  activeText: "󰂛"
  inactiveText: "󰂛"
  activeTooltipText: "Allow Notifications"
  inactiveTooltipText: "Silence Notifications"

  onPressed: function() {
    if (root.notificationService) {
      root.notificationService.setDoNotDisturb(!root.notificationService.doNotDisturb)
    }
  }
}
