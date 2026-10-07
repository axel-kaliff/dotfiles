// Open an event from a calopen URL because Thunderbird has no CLI flag for one event.
var { ExtensionCommon } = ChromeUtils.importESModule("resource://gre/modules/ExtensionCommon.sys.mjs");
var { cal } = ChromeUtils.importESModule("resource:///modules/calendar/calUtils.sys.mjs");
// Experiment scripts run in a sandbox without the web URL global.
Cu.importGlobalProperties(["URL"]);

async function openItem(params) {
  const item = await cal.manager.getCalendarById(params.get("cal")).getItem(params.get("id"));
  const occurrence = item.recurrenceInfo
    ? item.recurrenceInfo.getOccurrenceFor(cal.createDateTime(params.get("rid")))
    : item;
  Services.wm.getMostRecentWindow("mail:3pane").openEventDialogForViewing(occurrence);
}

const handler = {
  classID: Components.ID("{d8c5be47-1cb5-48e2-9cca-6626aec88099}"),
  contractID: "@akaliff/calopen-url-handler;1",
  QueryInterface: ChromeUtils.generateQI(["nsIObserver", "nsIFactory"]),
  createInstance(iid) { return this.QueryInterface(iid); },
  observe(subject, topic, data) {
    if (topic == "net-thunderbird-url") openItem(new URL(data).searchParams);
  },
};

this.calopen = class extends ExtensionCommon.ExtensionAPI {
  onStartup() {
    Components.manager.QueryInterface(Ci.nsIComponentRegistrar).registerFactory(
      handler.classID, "calopen URL handler", handler.contractID, handler
    );
    Services.catMan.addCategoryEntry("net-thunderbird-url", "calopen", handler.contractID, false, true);
  }

  onShutdown(isAppShutdown) {
    if (isAppShutdown) return;
    Services.catMan.deleteCategoryEntry("net-thunderbird-url", "calopen", false);
    Components.manager.QueryInterface(Ci.nsIComponentRegistrar).unregisterFactory(handler.classID, handler);
  }

  getAPI() { return { calopen: {} }; }
};
