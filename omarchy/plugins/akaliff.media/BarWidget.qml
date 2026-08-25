import QtQuick
import Quickshell
import qs.Ui
import qs.Commons

BarWidget {
  id: root
  moduleName: "akaliff.media"

  readonly property var mediaService: bar?.shell?.serviceFor(root.moduleName)
  readonly property var activePlayer: mediaService ? mediaService.activePlayer : null
  readonly property var sourcePlayers: mediaService ? mediaService.sourcePlayers : []

  readonly property bool hasMedia: activePlayer !== null && (activePlayer.trackTitle || activePlayer.trackArtist)
  readonly property string playIcon: (activePlayer ? activePlayer.isPlaying : shownPlaying) ? "󰏤" : "󰐊"
  readonly property string title: activePlayer ? (activePlayer.trackTitle || "") : ""
  readonly property string artist: activePlayer ? (activePlayer.trackArtist || "") : ""

  property bool popupOpen: false

  // Firefox and friends register their Mpris name per media session and drop
  // it while a video rebuffers after a seek, so the player briefly vanishes.
  // Binding geometry straight to that collapses the widget to zero width and
  // shoves the rest of the bar sideways on every skip, so mirror the last live
  // state and keep showing it across a short gap. The popup deliberately stays
  // bound to the real player: its controls are dead while the player is gone.
  property bool showMedia: false
  property string shownKey: ""
  property string shownTitle: ""
  property string shownArtist: ""
  property bool shownPlaying: false

  function shownPlayerGone() {
    if (!shownKey || !mediaService) return false
    var list = mediaService.players || []
    for (var i = 0; i < list.length; i++) {
      if (mediaService.playerKey(list[i]) === shownKey) return false
    }
    return true
  }

  function adoptCurrent() {
    shownKey = ""
    syncShown()
  }

  function syncShown() {
    if (!hasMedia) {
      gapTimer.restart()
      return
    }

    // A different player is on offer. When the one we were showing merely
    // vanished, give it a moment to come back before flipping: a browser gets
    // a fresh Mpris name every time it re-registers, so the replacement here
    // is usually about to be superseded by the same app returning. A switch
    // while the old player is still on the bus is a real one - user selection
    // or auto-follow - and is taken immediately.
    var key = mediaService ? mediaService.playerKey(activePlayer) : ""
    if (showMedia && key !== shownKey && shownPlayerGone()) {
      if (!flipTimer.running) flipTimer.restart()
      return
    }

    gapTimer.stop()
    flipTimer.stop()
    showMedia = true
    shownKey = key
    shownTitle = title
    shownArtist = artist
    shownPlaying = activePlayer.isPlaying
  }

  Timer {
    id: flipTimer
    interval: 400
    onTriggered: root.adoptCurrent()
  }

  // The strip is the only importer of the native Lateralus.ProjectM module.
  // Probing it once at startup (instead of letting the Loader fail on first
  // open) reserves the strip's popup space before the card maps, and turns a
  // missing plugin — older image, non-lateralus machine — into a single log
  // line with the popup byte-identical to the pre-visualizer layout.
  property var visualizerComponent: null
  readonly property bool visualizerAvailable: visualizerComponent !== null
    && visualizerComponent.status === Component.Ready

  Component.onCompleted: {
    syncShown()
    var comp = Qt.createComponent("VisualizerStrip.qml", Component.PreferSynchronous)
    if (comp.status === Component.Ready) visualizerComponent = comp
    else console.log("media: projectM visualizer unavailable: " + comp.errorString())
  }
  onHasMediaChanged: syncShown()
  onTitleChanged: syncShown()
  onArtistChanged: syncShown()

  Connections {
    target: root.activePlayer
    function onIsPlayingChanged() { root.syncShown() }
  }

  Timer {
    id: gapTimer
    interval: 1500
    onTriggered: root.showMedia = false
  }

  readonly property bool canSeek: activePlayer !== null && activePlayer.canSeek && activePlayer.positionSupported
  readonly property bool canRaise: activePlayer !== null && activePlayer.canRaise
  readonly property real trackLength: activePlayer && activePlayer.lengthSupported ? activePlayer.length : 0
  readonly property real trackPosition: activePlayer && activePlayer.positionSupported ? activePlayer.position : 0

  function formatTime(seconds) {
    var total = Math.max(0, Math.floor(seconds))
    var s = total % 60
    var m = Math.floor(total / 60) % 60
    var h = Math.floor(total / 3600)
    return (h > 0 ? h + ":" + (m < 10 ? "0" + m : m) : String(m)) + ":" + (s < 10 ? "0" + s : s)
  }

  // Mpris position is not reactive: Quickshell re-reads it only when
  // positionChanged() fires. Tick while the popup is showing the scrubber, and
  // refresh once on open so it starts from the current position instead of
  // wherever the last nonlinear jump left it.
  onPopupOpenChanged: if (popupOpen && activePlayer) activePlayer.positionChanged()

  Timer {
    running: root.popupOpen && root.activePlayer !== null && root.activePlayer.isPlaying
    interval: 1000
    repeat: true
    onTriggered: root.activePlayer.positionChanged()
  }

  function close() { popupOpen = false }
  property real maxLabelWidth: 180

  visible: showMedia
  implicitWidth: showMedia ? row.implicitWidth + Style.space(14) : 0
  implicitHeight: barSize

  Row {
    id: row
    anchors.centerIn: parent
    spacing: Style.space(6)

    Text {
      id: glyph
      anchors.verticalCenter: parent.verticalCenter
      text: root.playIcon
      color: activePlayer && activePlayer.isPlaying ? root.bar.barForeground : Qt.darker(root.bar.barForeground, 1.5)
      font.family: root.bar.fontFamily
      font.pixelSize: Style.font.body
      Behavior on color {
        enabled: !root.bar || root.bar.foregroundAnimationEnabled
        ColorAnimation { duration: 160 }
      }
    }

    Item {
      id: scrollClip
      width: Math.min(root.maxLabelWidth, labelText.implicitWidth)
      height: glyph.height
      clip: true
      anchors.verticalCenter: parent.verticalCenter
      visible: !root.bar.vertical && root.shownTitle !== ""

      Text {
        id: labelText
        text: root.shownTitle + (root.shownArtist ? "  ·  " + root.shownArtist : "")
        color: root.bar.barForeground
        font.family: root.bar.fontFamily
        font.pixelSize: Style.font.body
        anchors.verticalCenter: parent.verticalCenter

        property bool needsScroll: implicitWidth > scrollClip.width

        // The scroll animation is a value source on x, so stopping it strands x
        // at its `from` (the clip width). A track change to a title short enough
        // not to scroll then leaves the label parked off the clip's right edge,
        // showing a title-width hole in the bar instead of the title.
        onNeedsScrollChanged: if (!needsScroll) x = 0

        NumberAnimation on x {
          id: scrollAnim
          running: labelText.needsScroll && !root.popupOpen && !root.bar.vertical
          loops: Animation.Infinite
          duration: Math.max(6000, labelText.implicitWidth * 25)
          from: scrollClip.width
          to: -labelText.implicitWidth
          easing.type: Easing.Linear
        }
      }
    }
  }

  MouseArea {
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: root.activePlayer ? Qt.PointingHandCursor : Qt.ArrowCursor
    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton

    onClicked: function(mouse) {
      if (!root.activePlayer) return
      if (mouse.button === Qt.MiddleButton) {
        if (root.mediaService) root.mediaService.runAction("next", false)
      } else if (mouse.button === Qt.RightButton) {
        if (root.mediaService) root.mediaService.runAction("playPause", false)
      } else {
        root.popupOpen = !root.popupOpen
      }
    }
    onWheel: function(wheel) {
      if (!root.activePlayer) return
      if (wheel.angleDelta.y > 0 && root.mediaService) root.mediaService.runAction("previous", false)
      else if (wheel.angleDelta.y < 0 && root.mediaService) root.mediaService.runAction("next", false)
    }
    onEntered: if (root.bar) root.bar.showTooltip(root, root.showMedia ? (root.shownTitle + (root.shownArtist ? " — " + root.shownArtist : "")) : "")
    onExited: if (root.bar) root.bar.hideTooltip(root)
  }

  PopupCard {
    id: popup
    anchorItem: root
    bar: root.bar
    owner: root
    open: root.popupOpen
    contentWidth: popup.fittedContentWidth(Style.space(320))
    contentHeight: popup.fittedContentHeight(column.implicitHeight)

    Column {
      id: column
      anchors.fill: parent
      spacing: Style.space(10)

      Row {
        spacing: Style.space(10)
        width: parent.width

        BorderSurface {
          width: Style.space(64)
          height: Style.space(64)
          radius: Style.spacing.labelGap
          color: Style.normalFillFor(root.bar.foreground, Color.accent)
          borderSpec: Border.controlSpec("normal", root.bar.foreground, Color.accent)

          Image {
            anchors.fill: parent
            anchors.margins: Style.space(2)
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            source: root.activePlayer && root.activePlayer.trackArtUrl ? root.activePlayer.trackArtUrl : ""
            visible: source !== ""
          }

          Text {
            anchors.centerIn: parent
            visible: !root.activePlayer || !root.activePlayer.trackArtUrl
            text: "󰝚"
            color: root.bar.foreground
            font.family: root.bar.fontFamily
            font.pixelSize: Style.font.displayLarge
          }

          // Mpris Raise() rather than a Hyprland focus dispatch: it is the
          // player's own "come to the front" call, so it works for whatever is
          // playing without mapping desktop entries to window classes.
          MouseArea {
            anchors.fill: parent
            enabled: root.canRaise
            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: {
              root.activePlayer.raise()
              root.close()
            }
          }
        }

        Column {
          spacing: Style.space(4)
          width: parent.width - Style.space(74)

          Text {
            text: root.title || "Nothing playing"
            color: root.bar.foreground
            font.family: root.bar.fontFamily
            font.pixelSize: Style.font.subtitle
            font.bold: true
            elide: Text.ElideRight
            width: parent.width
          }

          Text {
            text: root.artist
            color: Qt.darker(root.bar.foreground, 1.3)
            font.family: root.bar.fontFamily
            font.pixelSize: Style.font.bodySmall
            elide: Text.ElideRight
            width: parent.width
            visible: text !== ""
          }

          Text {
            text: root.activePlayer && root.activePlayer.trackAlbum ? root.activePlayer.trackAlbum : ""
            color: Qt.darker(root.bar.foreground, 1.6)
            font.family: root.bar.fontFamily
            font.pixelSize: Style.font.caption
            elide: Text.ElideRight
            width: parent.width
            visible: text !== ""
          }
        }
      }

      Loader {
        id: visualizerLoader
        width: parent.width
        height: Style.space(root.setting("visualizerHeight", 130))
        // popup.visible, not root.popupOpen: the card keeps fading for 140ms
        // after open flips false, and unloading then leaves a hole mid-fade.
        active: popup.visible && root.visualizerAvailable && root.setting("visualizer", true)
        visible: active
        asynchronous: true
        sourceComponent: root.visualizerComponent
        onLoaded: {
          item.bar = Qt.binding(function() { return root.bar })
          item.playing = Qt.binding(function() { return root.activePlayer !== null && root.activePlayer.isPlaying })
          item.presetDuration = root.setting("presetDuration", 30)
        }
      }

      Column {
        width: parent.width
        spacing: Style.space(2)
        visible: root.canSeek && root.trackLength > 0

        PanelSlider {
          id: scrubber
          bar: root.bar
          width: parent.width
          minimum: 0
          maximum: root.trackLength
          value: root.trackPosition
          onReleased: function(seconds) { if (root.mediaService) root.mediaService.seekTo(seconds) }
        }

        Item {
          width: parent.width
          height: elapsed.implicitHeight

          Text {
            id: elapsed
            anchors.left: parent.left
            text: root.formatTime(scrubber.dragging ? scrubber.liveValue : root.trackPosition)
            color: Qt.darker(root.bar.foreground, 1.3)
            font.family: root.bar.fontFamily
            font.pixelSize: Style.font.caption
          }

          Text {
            anchors.right: parent.right
            text: root.formatTime(root.trackLength)
            color: Qt.darker(root.bar.foreground, 1.6)
            font.family: root.bar.fontFamily
            font.pixelSize: Style.font.caption
          }
        }
      }

      Row {
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: Style.space(6)

        Button {
          iconText: "󰒮"
          foreground: root.bar.foreground
          horizontalPadding: Style.spacing.controlPaddingX
          verticalPadding: Style.spacing.controlPaddingY
          enabled: root.activePlayer && root.activePlayer.canGoPrevious
          opacity: enabled ? 1.0 : 0.4
          onClicked: if (root.mediaService) root.mediaService.runAction("previous", false, root.mediaService.playerKey(root.activePlayer))
        }

        Button {
          iconText: "󱥆"
          foreground: root.bar.foreground
          horizontalPadding: Style.spacing.controlPaddingX
          verticalPadding: Style.spacing.controlPaddingY
          enabled: root.canSeek
          opacity: enabled ? 1.0 : 0.4
          onClicked: if (root.mediaService) root.mediaService.seekBy(-15)
        }

        Button {
          iconText: root.activePlayer && root.activePlayer.isPlaying ? "󰏤" : "󰐊"
          foreground: root.bar.foreground
          horizontalPadding: Style.spacing.panelGap
          verticalPadding: Style.spacing.controlPaddingY
          iconSize: Style.font.iconLarge
          enabled: root.activePlayer && (root.activePlayer.canTogglePlaying || root.activePlayer.canPlay || root.activePlayer.canPause)
          opacity: enabled ? 1.0 : 0.4
          onClicked: if (root.mediaService) root.mediaService.runAction("playPause", false, root.mediaService.playerKey(root.activePlayer))
        }

        Button {
          iconText: "󱤺"
          foreground: root.bar.foreground
          horizontalPadding: Style.spacing.controlPaddingX
          verticalPadding: Style.spacing.controlPaddingY
          enabled: root.canSeek
          opacity: enabled ? 1.0 : 0.4
          onClicked: if (root.mediaService) root.mediaService.seekBy(15)
        }

        Button {
          iconText: "󰒭"
          foreground: root.bar.foreground
          horizontalPadding: Style.spacing.controlPaddingX
          verticalPadding: Style.spacing.controlPaddingY
          enabled: root.activePlayer && root.activePlayer.canGoNext
          opacity: enabled ? 1.0 : 0.4
          onClicked: if (root.mediaService) root.mediaService.runAction("next", false, root.mediaService.playerKey(root.activePlayer))
        }
      }

      PanelSeparator {
        visible: root.sourcePlayers.length > 1
        foreground: root.bar.foreground
      }

      Column {
        id: sourceList
        visible: root.sourcePlayers.length > 1
        width: parent.width
        spacing: Style.space(4)

        Repeater {
          model: root.sourcePlayers

          BorderSurface {
            id: sourceRow
            required property var modelData

            readonly property var player: modelData
            readonly property bool selected: root.activePlayer && player
              && root.mediaService.playerKey(root.activePlayer) === root.mediaService.playerKey(player)
            readonly property string sourceTitle: player ? (player.trackTitle || player.identity || player.desktopEntry || "Media source") : "Media source"
            readonly property string sourceDetail: player && player.trackArtist ? player.trackArtist : (player && player.identity ? player.identity : "")

            width: sourceList.width
            height: sourceInner.implicitHeight + Style.space(10)
            radius: Style.spacing.labelGap
            color: selected ? Style.selectedFillFor(root.bar.foreground, Color.accent) : "transparent"
            borderSpec: selected ? Border.controlSpec("normal", root.bar.foreground, Color.accent) : Border.none()

            Row {
              id: sourceInner
              z: 1
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              anchors.leftMargin: sourceRow.borderLeft + Style.space(8)
              anchors.rightMargin: sourceRow.borderRight + Style.space(8)
              spacing: Style.space(8)

              Text {
                text: sourceRow.player && sourceRow.player.isPlaying ? "󰏤" : "󰐊"
                color: root.bar.foreground
                font.family: root.bar.fontFamily
                font.pixelSize: Style.font.body
                width: Style.space(18)
                horizontalAlignment: Text.AlignHCenter
                anchors.verticalCenter: parent.verticalCenter

                MouseArea {
                  anchors.fill: parent
                  anchors.topMargin: -Style.space(8)
                  anchors.bottomMargin: -Style.space(8)
                  enabled: sourceRow.player && root.mediaService
                    && root.mediaService.canHandleAction(sourceRow.player, "playPause")
                  cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                  onClicked: root.mediaService.runAction("playPause", false,
                                                         root.mediaService.playerKey(sourceRow.player))
                }
              }

              Column {
                width: parent.width - Style.space(26)
                spacing: Style.space(1)
                anchors.verticalCenter: parent.verticalCenter

                Text {
                  text: sourceRow.sourceTitle
                  color: root.bar.foreground
                  font.family: root.bar.fontFamily
                  font.pixelSize: Style.font.bodySmall
                  font.bold: sourceRow.selected
                  elide: Text.ElideRight
                  width: parent.width
                }

                Text {
                  text: sourceRow.sourceDetail
                  color: Qt.darker(root.bar.foreground, 1.5)
                  font.family: root.bar.fontFamily
                  font.pixelSize: Style.font.caption
                  elide: Text.ElideRight
                  width: parent.width
                  visible: text !== ""
                }
              }
            }

            MouseArea {
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: if (root.mediaService) root.mediaService.selectPlayer(root.mediaService.playerKey(sourceRow.player))
            }
          }
        }
      }

      // Bongocat from caelestia-dots/shell (soramanew), bopping while music
      // plays; AnimatedImage freezes on the current frame when playback stops.
      // The asset already ships as a white cat on transparency, so it sits on
      // the dark popup untouched.
      AnimatedImage {
        width: parent.width
        height: Style.space(72)
        source: Qt.resolvedUrl("bongocat.gif")
        playing: root.activePlayer !== null && root.activePlayer.isPlaying === true
        asynchronous: true
        fillMode: AnimatedImage.PreserveAspectFit
      }
    }
  }
}
