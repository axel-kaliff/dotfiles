import QtQuick
import Quickshell.Io

// Icon names to file paths.
//
// Quickshell 0.3.0 on this machine resolves nothing through Qt's icon theme:
// hasThemeIcon("btop") is false even though btop.svg sits in hicolor, in the
// default search path. iconPath(name, true) therefore returns "" for every
// name, and iconPath(name) returns a provider URL that renders as Qt's 2x2
// magenta placeholder. Both bar widgets that want an app icon go through here
// instead, and get a path they can hand straight to an Image.
//
// The index is built once at startup. An app installed afterwards is missing
// from it until the next shell restart.
Item {
  id: service

  readonly property string script:
    Qt.resolvedUrl("bin/index-icons").toString().replace(/^file:\/\//, "")

  property var index: ({})

  // Absolute path for an icon name, or "" when the name is unknown. A value
  // that is already a path is passed back unchanged, so a caller can hand
  // over whatever the notification gave it without checking first.
  function pathFor(name) {
    var key = String(name || "")
    if (key === "" || key.charAt(0) === "/") return key
    var hit = service.index[key]
    return hit ? hit : ""
  }

  Process {
    command: [service.script]
    running: true

    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var next = ({})
        var lines = text.split("\n")
        for (var i = 0; i < lines.length; i++) {
          var parts = lines[i].split("\t")
          if (parts.length === 2 && parts[0] !== "") next[parts[0]] = parts[1]
        }
        service.index = next
      }
    }
  }
}
