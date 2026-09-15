import QtQuick
import QtQuick.Controls.Basic as Controls
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Mpris
import qs.Commons

PanelWindow {
  id: root
  property bool available: false
  property var cards: []
  property int currentIndex: 0
  property bool expanded: false
  property real dockX: 0
  property real dockY: 0
  property real dockHeight: 82
  property color paletteBackground: Color.background
  property color paletteForeground: Color.foreground
  property color paletteAccent: Color.accent
  readonly property bool engaged: visible && (expanded || hover.hovered)
  readonly property var card: cards.length ? cards[Math.min(currentIndex, cards.length - 1)] : null
  readonly property string kind: card ? card.type : ""
  readonly property string iconName: kind === "music" ? "musical-notes" : kind === "clock" ? "time" : "partly-sunny"
  readonly property var players: Mpris.players.values
  readonly property var player: {
    if (card && card.player) {
      for (var i = 0; i < players.length; i++) if (players[i].identity === card.player) return players[i]
      return null
    }
    for (var j = 0; j < players.length; j++) if (players[j].isPlaying) return players[j]
    return players.length ? players[0] : null
  }
  property date now: new Date()
  property string weatherText: "Loading weather…"
  readonly property bool hasWeather: cards.some(function(c) { return c.type === "weather" })
  signal cardsAdjusted(var value)
  onCardsChanged: { currentIndex = Math.max(0, Math.min(currentIndex, cards.length - 1)); if (!cards.length) expanded = false }
  onAvailableChanged: if (!available) expanded = false
  onHasWeatherChanged: if (hasWeather) refreshWeather()
  function step(amount) {
    if (cards.length) currentIndex = (currentIndex + amount + cards.length) % cards.length
  }
  function refreshWeather() { if (hasWeather && !weatherProcess.running) weatherProcess.running = true }
  function choosePlayer() {
    if (!card) return
    var identities = [""]
    for (var i = 0; i < players.length; i++) if (identities.indexOf(players[i].identity) === -1) identities.push(players[i].identity)
    var index = identities.indexOf(card.player || "")
    var updated = cards.slice()
    updated[currentIndex] = { type: "music", player: identities[(index + 1) % identities.length] }
    cardsAdjusted(updated)
  }
  visible: available && cards.length > 0
  color: "transparent"
  exclusionMode: ExclusionMode.Ignore
  WlrLayershell.layer: WlrLayer.Overlay
  WlrLayershell.namespace: "my-dock-widget-stack"
  WlrLayershell.keyboardFocus: expanded ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
  anchors { top: true; bottom: true; left: true; right: true }
  mask: Region { item: surface }

  Timer { interval: 1000; running: root.visible && root.kind === "clock"; repeat: true; triggeredOnStart: true; onTriggered: root.now = new Date() }
  Timer { interval: 900000; running: root.hasWeather; repeat: true; onTriggered: root.refreshWeather() }
  Process {
    id: weatherProcess
    command: ["timeout", "12s", "omarchy-weather-status"]
    stdout: StdioCollector { onStreamFinished: root.weatherText = String(text).trim() || "Weather unavailable. Check your connection and Omarchy location." }
    onExited: function(code) { if (code !== 0) root.weatherText = "Weather unavailable. Check your connection and Omarchy location." }
  }

  Rectangle {
    id: surface
    width: root.expanded ? Math.min(320, root.width - 16) : 56
    height: root.expanded ? Math.min(300, root.height - 16) : 64
    // The widget is a separate surface: it never participates in app layout.
    x: Math.max(8, Math.min(root.width - width - 8, root.dockX - width - 10))
    y: Math.max(8, Math.min(root.height - height - 8, root.dockY + root.dockHeight - height))
    radius: 16
    color: root.paletteBackground
    border.color: Util.alpha(root.paletteAccent, 0.5)
    border.width: 1
    HoverHandler { id: hover }
    WheelHandler { onWheel: function(event) { root.step(event.angleDelta.y < 0 ? 1 : -1); event.accepted = true } }
    Keys.onEscapePressed: root.expanded = false
    onVisibleChanged: if (visible) forceActiveFocus()

    Item {
      anchors.fill: parent
      visible: !root.expanded
      ThemedIcon {
        anchors.horizontalCenter: parent.horizontalCenter; y: 8
        width: 28; height: 28; iconColor: root.paletteForeground
        source: Qt.resolvedUrl("assets/widget-" + root.iconName + ".svg")
      }
      Text {
        anchors.horizontalCenter: parent.horizontalCenter; y: 41
        text: (root.currentIndex + 1) + "/" + root.cards.length
        color: root.paletteForeground; font.pixelSize: 10
      }
      Accessible.role: Accessible.Button
      Accessible.name: "Expand " + root.kind + " widget stack"
      MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { root.expanded = true; surface.forceActiveFocus() } }
    }

    Column {
      visible: root.expanded
      anchors.fill: parent; anchors.margins: 16; spacing: 12
      Row {
        width: parent.width; spacing: 8
        WidgetButton { icon: "chevron-back"; label: "Previous widget"; enabled: root.cards.length > 1; onClicked: root.step(-1) }
        Text {
          width: parent.width - 120; height: 32
          text: root.kind.charAt(0).toUpperCase() + root.kind.slice(1) + " · " + (root.currentIndex + 1) + "/" + root.cards.length
          color: root.paletteForeground; font.bold: true; verticalAlignment: Text.AlignVCenter; elide: Text.ElideRight
        }
        WidgetButton { icon: "chevron-forward"; label: "Next widget"; enabled: root.cards.length > 1; onClicked: root.step(1) }
        WidgetButton { icon: "expand"; label: "Collapse widget"; onClicked: root.expanded = false }
      }
      Column {
        width: parent.width; spacing: 10; visible: root.kind === "music"
        Text { width: parent.width; text: root.player ? (root.player.trackTitle || "Nothing playing") : "No media player"; color: root.paletteForeground; font.pixelSize: 18; maximumLineCount: 2; wrapMode: Text.Wrap; elide: Text.ElideRight }
        Text { width: parent.width; text: root.player ? (root.player.trackArtist || root.player.identity) : "Start music in a compatible app."; color: Util.alpha(root.paletteForeground, 0.7); elide: Text.ElideRight }
        Row {
          spacing: 16
          WidgetButton { icon: "play-skip-back"; label: "Previous track"; enabled: !!root.player && root.player.canGoPrevious; onClicked: root.player.previous() }
          WidgetButton { icon: root.player && root.player.isPlaying ? "pause" : "play"; label: "Play or pause"; enabled: !!root.player && root.player.canTogglePlaying; onClicked: root.player.togglePlaying() }
          WidgetButton { icon: "play-skip-forward"; label: "Next track"; enabled: !!root.player && root.player.canGoNext; onClicked: root.player.next() }
        }
        Controls.Button {
          width: parent.width; text: "Player: " + (root.card && root.card.player ? root.card.player : "Automatic")
          onClicked: root.choosePlayer()
          contentItem: Text { text: parent.text; color: root.paletteForeground; elide: Text.ElideRight; horizontalAlignment: Text.AlignHCenter }
          background: Rectangle { radius: 8; color: Util.alpha(root.paletteAccent, 0.15) }
        }
        Text { text: "Click Player to switch sources."; color: Util.alpha(root.paletteForeground, 0.6); font.pixelSize: 11 }
      }
      Column {
        width: parent.width; spacing: 12; visible: root.kind === "clock"
        Text { text: Qt.formatDateTime(root.now, "HH:mm:ss"); color: root.paletteForeground; font.pixelSize: 38 }
        Text { width: parent.width; text: Qt.formatDateTime(root.now, "dddd, d MMMM yyyy"); color: root.paletteForeground; wrapMode: Text.Wrap }
        Text { text: "Local time"; color: Util.alpha(root.paletteForeground, 0.6) }
      }
      Column {
        width: parent.width; spacing: 12; visible: root.kind === "weather"
        ThemedIcon { width: 40; height: 40; source: Qt.resolvedUrl("assets/widget-partly-sunny.svg"); iconColor: root.paletteAccent }
        Text { width: parent.width; text: root.weatherText; wrapMode: Text.Wrap; color: root.paletteForeground; maximumLineCount: 5; elide: Text.ElideRight }
        Controls.Button {
          text: weatherProcess.running ? "Refreshing…" : "Refresh weather"; enabled: !weatherProcess.running
          onClicked: root.refreshWeather()
          contentItem: Text { text: parent.text; color: root.paletteForeground }
          background: Rectangle { radius: 8; color: Util.alpha(root.paletteAccent, 0.15) }
        }
      }
    }
  }

  component WidgetButton: Rectangle {
    property string icon: ""
    property string label: ""
    signal clicked()
    width: 32; height: 32; radius: 8
    opacity: enabled ? 1 : 0.35
    color: buttonMouse.containsMouse ? Util.alpha(root.paletteAccent, 0.25) : Util.alpha(root.paletteForeground, 0.06)
    ThemedIcon { anchors.centerIn: parent; width: 22; height: 22; iconColor: root.paletteForeground; source: Qt.resolvedUrl("assets/widget-" + parent.icon + ".svg") }
    Accessible.role: Accessible.Button
    Accessible.name: label
    MouseArea { id: buttonMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: parent.clicked() }
  }
}
