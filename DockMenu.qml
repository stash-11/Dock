import "."
import QtQuick
import QtQuick.Controls.Basic as Controls
import Quickshell
import Quickshell.Wayland
import qs.Commons
import qs.Ui

PanelWindow {
  id: root

  property var itemData: null
  property string iconSource: ""
  property bool opened: false
  property bool settingsPage: false
  property string settingsSection: "appearance"
  property string screenshotOutput: "slurp"
  property string version: "1.0.0"
  signal screenshotOutputAdjusted(string value)
  onOpenedChanged: if (!opened) settingsPage = false
  property point requestedPosition: Qt.point(0, 0)
  property bool autoHideEnabled: true
  property string dockSide: "bottom"
  property real magnification: 1.85
  property real roundness: 1
  property real transparency: 0.14
  signal transparencyAdjusted(real value)
  property string appearanceMode: "theme"
  readonly property color paletteBackground: appearanceMode === "theme" ? Color.background : "#242426"
  readonly property color paletteForeground: appearanceMode === "theme" ? Color.foreground : "#f5f5f7"
  readonly property color paletteAccent: appearanceMode === "theme" ? Color.accent : "#0a84ff"
  signal appearanceModeAdjusted(string value)
  signal magnificationAdjusted(real value)
  signal roundnessAdjusted(real value)

  signal actionTriggered(string action, var itemData)

  visible: opened && (settingsPage || itemData !== null)
  color: "transparent"
  exclusionMode: ExclusionMode.Ignore
  WlrLayershell.layer: WlrLayer.Overlay
  WlrLayershell.namespace: "io.github.stash-11-dock-menu"
  anchors { top: true; bottom: true; left: true; right: true }
  mask: Region { item: dismissSurface }

  Rectangle {
    id: card
    x: Math.round((root.width - width) / 2)
    y: Math.round((root.height - height) / 2)
    width: root.settingsPage ? Math.min(850, root.width - 32) : 650
    height: root.settingsPage ? Math.min(560, root.height - 32) : 290
    radius: 22
    color: Util.alpha(root.paletteBackground, 0.97)
    border.color: Util.alpha(root.paletteForeground, 0.14)
    border.width: 1

    Column {
      visible: !root.settingsPage
      anchors.fill: parent
      anchors.margins: 22
      spacing: 16

      Item {
        width: parent.width
        height: 58

        Rectangle {
          width: 58
          height: 58
          radius: 16
          anchors.left: parent.left
          color: Util.alpha(root.paletteForeground, 0.08)

          Image {
            id: appIcon
            anchors.centerIn: parent
            width: 48
            height: 48
            source: root.iconSource
            sourceSize: Qt.size(96, 96)
            fillMode: Image.PreserveAspectFit
            visible: !root.settingsPage && status === Image.Ready
          }
          Image {
            anchors.centerIn: parent
            width: 32; height: 32
            source: Qt.resolvedUrl("assets/settings.svg")
            sourceSize: Qt.size(64, 64)
            visible: root.settingsPage
          }
          Text {
            anchors.centerIn: parent
            text: root.itemData && root.itemData.name ? String(root.itemData.name).charAt(0).toUpperCase() : "•"
            color: root.paletteForeground
            font.family: Style.font.family
            font.pixelSize: 24
            font.bold: true
            visible: !root.settingsPage && !appIcon.visible
          }
        }

        Column {
          anchors.left: parent.left
          anchors.leftMargin: 72
          anchors.verticalCenter: parent.verticalCenter
          spacing: 3
          Text {
            text: root.settingsPage ? "Dock Settings" : (root.itemData && root.itemData.name ? root.itemData.name : "Application")
            color: root.paletteForeground
            font.family: Style.font.family
            font.pixelSize: Style.font.title
            font.bold: true
          }
          Text {
            text: root.settingsPage ? "Position, hiding and appearance" : (root.itemData && root.itemData.running ? "Running application" : "Pinned application")
            color: Util.alpha(root.paletteForeground, 0.52)
            font.family: Style.font.family
            font.pixelSize: Style.font.bodySmall
          }
        }

        Rectangle {
          width: 32; height: 32; radius: 16
          anchors.right: parent.right
          anchors.rightMargin: 42
          anchors.verticalCenter: parent.verticalCenter
          color: settingsMouse.containsMouse ? Util.alpha(root.paletteForeground, 0.12) : "transparent"
          Accessible.role: Accessible.Button
          Accessible.name: root.settingsPage ? "Back to application actions" : "Dock settings"
          Image {
            anchors.centerIn: parent
            width: 22; height: 22
            source: Qt.resolvedUrl(root.settingsPage ? "assets/back.svg" : "assets/settings.svg")
            sourceSize: Qt.size(44, 44)
            smooth: true
          }
          MouseArea {
            id: settingsMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.settingsPage = !root.settingsPage
          }
        }

        Rectangle {
          width: 32
          height: 32
          anchors.right: parent.right
          radius: 16
          anchors.verticalCenter: parent.verticalCenter
          color: closeMouse.containsMouse ? Util.alpha(root.paletteForeground, 0.12) : "transparent"
          Accessible.role: Accessible.Button
          Accessible.name: "Close"
          Image {
            anchors.centerIn: parent
            width: 22; height: 22
            source: Qt.resolvedUrl("assets/close.svg")
            sourceSize: Qt.size(44, 44)
            smooth: true
          }
          MouseArea { id: closeMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.opened = false }
        }
      }

      Rectangle { width: parent.width; height: 1; color: Util.alpha(root.paletteForeground, 0.10) }

      Text {
        visible: !root.settingsPage
        text: "Application actions"
        color: root.paletteForeground
        font.family: Style.font.family
        font.pixelSize: Style.font.heading
        font.bold: true
      }

      Row {
        visible: !root.settingsPage
        width: parent.width
        height: 112
        spacing: 10

        Repeater {
          model: [
            { action: "setIcon", label: "Get Info", glyph: "✦", detail: "Change icon" },
            { action: "togglePin", label: root.itemData && root.itemData.pinned ? "Unpin" : "Pin", glyph: "⌖", detail: "Dock placement" },
            { action: "newWindow", label: "New Window", glyph: "＋", detail: "Open another" },
            { action: "manageIcons", label: "Manage Icons", glyph: "▦", detail: "Browse apps" }
          ]
          delegate: Rectangle {
            required property var modelData
            width: (parent.width - 30) / 4
            height: parent.height
            radius: 14
            color: actionMouse.containsMouse ? Util.alpha(root.paletteAccent, 0.16) : Util.alpha(root.paletteForeground, 0.065)
            border.color: actionMouse.containsMouse ? Util.alpha(root.paletteAccent, 0.55) : "transparent"
            border.width: 1

            Column {
              anchors.centerIn: parent
              spacing: 8
              Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: modelData.glyph
                color: actionMouse.containsMouse ? root.paletteAccent : root.paletteForeground
                font.pixelSize: 24
              }
              Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: modelData.label
                color: root.paletteForeground
                font.family: Style.font.family
                font.pixelSize: Style.font.body
              }
              Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: modelData.detail
                color: Util.alpha(root.paletteForeground, 0.45)
                font.family: Style.font.family
                font.pixelSize: Style.font.bodySmall
              }
            }

            MouseArea {
              id: actionMouse
              anchors.fill: parent
              hoverEnabled: true
              onClicked: {
                root.actionTriggered(modelData.action, root.itemData)
              }
            }
          }
        }
      }

    }

    Item {
      visible: root.settingsPage
      anchors.fill: parent
      Rectangle {
        width: 214
        anchors.top: parent.top; anchors.bottom: parent.bottom
        radius: 22
        color: Util.alpha(root.paletteForeground, 0.035)
      }
      Rectangle {
        x: 214; width: 1; height: parent.height
        color: Util.alpha(root.paletteForeground, 0.1)
      }
      Column {
        x: 12; y: 24; width: 190; spacing: 6
        Text {
          text: "My Dock"; height: 44; leftPadding: 12
          color: root.paletteForeground; font.family: Style.font.family
          font.pixelSize: 21; font.bold: true
        }
        Repeater {
          model: [
            { key: "dock", title: "Dock Behavior", icon: "screenshot-fullscreen.svg" },
            { key: "appearance", title: "Appearance", icon: "settings.svg" },
            { key: "screenshots", title: "Screenshots", icon: "screenshot-region.svg" },
            { key: "shortcuts", title: "Shortcuts", icon: "screenshot-windows.svg" },
            { key: "about", title: "About", icon: "default-app.svg" }
          ]
          delegate: Rectangle {
            required property var modelData
            width: 190; height: 42; radius: 8
            color: root.settingsSection === modelData.key ? root.paletteAccent : sidebarMouse.containsMouse ? Util.alpha(root.paletteForeground, 0.07) : "transparent"
            Image {
              x: 10; anchors.verticalCenter: parent.verticalCenter
              width: 26; height: 26; source: Qt.resolvedUrl("assets/" + modelData.icon)
              sourceSize: Qt.size(52, 52)
            }
            Text {
              x: 46; anchors.verticalCenter: parent.verticalCenter
              text: modelData.title; font.family: Style.font.family; font.pixelSize: 14
              color: root.settingsSection === modelData.key ? "white" : root.paletteForeground
            }
            Accessible.role: Accessible.Button
            Accessible.name: modelData.title
            MouseArea {
              id: sidebarMouse; anchors.fill: parent; hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: root.settingsSection = modelData.key
            }
          }
        }
      }
      Flickable {
        x: 242; y: 26; width: parent.width - 270; height: parent.height - 106
        clip: true; contentHeight: settingsContent.height
        boundsBehavior: Flickable.StopAtBounds
        Column {
          id: settingsContent
          width: parent.width; spacing: 18
      Column {
        visible: root.settingsSection === "appearance"
        width: parent.width
        spacing: 8
        Text {
          text: "Appearance"
          color: root.paletteForeground
          font.family: Style.font.family
          font.pixelSize: Style.font.heading
          font.bold: true
          height: 28
          verticalAlignment: Text.AlignVCenter
        }
        Rectangle { width: parent.width; height: 1; color: Util.alpha(root.paletteForeground, 0.08) }
        Row {
          width: parent.width
          height: 38
          spacing: 8
          Text {
            width: 152
            anchors.verticalCenter: parent.verticalCenter
            text: "Colors"
            color: root.paletteForeground
            font.family: Style.font.family
            font.pixelSize: Style.font.bodySmall
          }
          UtilityButton { label: "Theme"; action: "appearanceTheme"; selected: root.appearanceMode === "theme"; width: 104 }
          UtilityButton { label: "Default"; action: "appearanceDefault"; selected: root.appearanceMode === "default"; width: 104 }
        }
        AppearanceControl {
          width: parent.width
          label: "Magnification"
          valueText: root.magnification <= 1 ? "Off" : root.magnification.toFixed(2) + "×"
          from: 1; to: 2.5; stepSize: 0.05
          value: root.magnification
          onAdjusted: function(value) { root.magnificationAdjusted(value) }
        }
        AppearanceControl {
          width: parent.width
          label: "Rounded corners"
          valueText: Math.round(root.roundness * 100) + "%"
          from: 0; to: 1; stepSize: 0.05
          value: root.roundness
          onAdjusted: function(value) { root.roundnessAdjusted(value) }
        }
        AppearanceControl {
          width: parent.width
          label: "Transparency"
          valueText: Math.round(root.transparency * 100) + "%"
          from: 0; to: 1; stepSize: 0.01
          value: root.transparency
          onAdjusted: function(value) { root.transparencyAdjusted(value) }
        }
      }
          Column {
            visible: root.settingsSection === "dock"
            width: parent.width; spacing: 18
            SectionTitle { text: "Dock Behavior" }
            SettingsText { text: "Choose where the dock lives and when it appears." }
            SettingsBox {
              width: parent.width; height: 76
              Text { x: 16; anchors.verticalCenter: parent.verticalCenter; text: "Automatically hide the dock"; color: root.paletteForeground; font.family: Style.font.family; font.pixelSize: 14 }
              UtilityButton { anchors.right: parent.right; anchors.rightMargin: 16; anchors.verticalCenter: parent.verticalCenter; width: 82; label: root.autoHideEnabled ? "On" : "Off"; selected: root.autoHideEnabled; action: "toggleAutoHide" }
            }
            SettingsText { text: "Position on screen" }
            Row {
              spacing: 8
              UtilityButton { label: "Bottom"; action: "setSideBottom"; selected: root.dockSide === "bottom"; width: 100 }
              UtilityButton { label: "Left"; action: "setSideLeft"; selected: root.dockSide === "left"; width: 100 }
              UtilityButton { label: "Right"; action: "setSideRight"; selected: root.dockSide === "right"; width: 100 }
            }
            SettingsText { text: "When hiding is on, move the pointer to the dock’s screen edge to reveal it." }
          }
          Column {
            visible: root.settingsSection === "screenshots"
            width: parent.width; spacing: 18
            SectionTitle { text: "Screenshots" }
            SettingsText { text: "Capture a window, your screen, or a selected area." }
            Row {
              spacing: 8
              UtilityButton { label: "Window"; action: "screenshot:windows"; width: 104 }
              UtilityButton { label: "Full Screen"; action: "screenshot:fullscreen"; width: 110 }
              UtilityButton { label: "Region"; action: "screenshot:region"; width: 104 }
            }
            SettingsText { text: "Save screenshots to" }
            Row {
              spacing: 8
              UtilityButton { label: "File + Clipboard"; action: "output:slurp"; selected: root.screenshotOutput === "slurp"; width: 140 }
              UtilityButton { label: "File"; action: "output:save"; selected: root.screenshotOutput === "save"; width: 82 }
              UtilityButton { label: "Clipboard"; action: "output:copy"; selected: root.screenshotOutput === "copy"; width: 104 }
            }
            SettingsText { text: "Files use your Omarchy screenshot folder (Pictures by default). The dock hides while you select a capture. Press Esc to cancel." }
            UtilityButton { label: "Show capture dock"; action: "showScreenshotDock"; width: 168 }
          }
          Column {
            visible: root.settingsSection === "shortcuts"
            width: parent.width; spacing: 18
            SectionTitle { text: "Shortcuts" }
            SettingsText { text: "Use these shortcuts to move between applications." }
            Repeater {
              model: [
                { label: "Next application", keys: "Alt + Tab" },
                { label: "Previous application", keys: "Alt + Shift + Tab" },
                { label: "Alternative app switcher", keys: "Alt + Grave" },
                { label: "Cancel capture or icon picker", keys: "Esc" }
              ]
              delegate: SettingsBox {
                required property var modelData
                width: settingsContent.width; height: 52
                Text { x: 14; anchors.verticalCenter: parent.verticalCenter; text: modelData.label; color: root.paletteForeground; font.family: Style.font.family; font.pixelSize: 13 }
                Text { anchors.right: parent.right; anchors.rightMargin: 14; anchors.verticalCenter: parent.verticalCenter; text: modelData.keys; color: root.paletteAccent; font.family: Style.font.family; font.pixelSize: 13 }
              }
            }
          }
          Column {
            visible: root.settingsSection === "about"
            width: parent.width; spacing: 18
            Image { width: 76; height: 76; source: Qt.resolvedUrl("assets/default-app.svg"); sourceSize: Qt.size(152, 152) }
            SectionTitle { text: "My Dock" }
            SettingsText { text: "Version " + root.version + " · by stash-11" }
            SettingsText { text: "A macOS-inspired dock for Omarchy, with app switching, custom icons, magnification, and screenshot controls." }
            SettingsText { text: "MIT License\nBased on the Omarchy dock by ifubaraboye." }
            UtilityButton { label: "View project on GitHub"; action: "openProject"; width: 202 }
          }
        }
      }
      Rectangle {
        x: 215; width: parent.width - x; height: 1; y: parent.height - 68
        color: Util.alpha(root.paletteForeground, 0.1)
      }
      Text {
        x: 242; anchors.bottom: parent.bottom; anchors.bottomMargin: 29
        text: "Changes save automatically"; color: Util.alpha(root.paletteForeground, 0.5)
        font.family: Style.font.family; font.pixelSize: 12
      }
      UtilityButton {
        anchors.right: parent.right; anchors.rightMargin: 26
        anchors.bottom: parent.bottom; anchors.bottomMargin: 18
        width: 86; label: "Done"; action: "closeSettings"; selected: true
      }
    }
  }

  component SectionTitle: Text {
    color: root.paletteForeground; font.family: Style.font.family
    font.pixelSize: 22; font.bold: true
  }
  component SettingsText: Text {
    width: parent.width; wrapMode: Text.WordWrap
    color: Util.alpha(root.paletteForeground, 0.65)
    font.family: Style.font.family; font.pixelSize: 14
    lineHeight: 1.25
  }
  component SettingsBox: Rectangle {
    radius: 10; color: Util.alpha(root.paletteForeground, 0.045)
    border.color: Util.alpha(root.paletteForeground, 0.1)
  }

  component AppearanceControl: Item {
    id: control
    property string label
    property string valueText
    property real from
    property real to
    property real stepSize
    property real value
    signal adjusted(real value)
    height: 44
    Text {
      anchors.left: parent.left
      anchors.verticalCenter: parent.verticalCenter
      text: control.label
      color: root.paletteForeground
      font.family: Style.font.family
      font.pixelSize: Style.font.bodySmall
    }
    Controls.Slider {
      id: slider
      // Explicit hit area: custom handles/tracks otherwise have zero implicit height.
      height: 40
      implicitHeight: 40
      padding: 9
      hoverEnabled: true
      focusPolicy: Qt.StrongFocus
      anchors.left: parent.left
      anchors.leftMargin: 160
      anchors.right: valueLabel.left
      anchors.rightMargin: 16
      anchors.verticalCenter: parent.verticalCenter
      from: control.from; to: control.to; stepSize: control.stepSize
      value: control.value
      onMoved: control.adjusted(value)
      Accessible.name: control.label
      HoverHandler {
        cursorShape: Qt.PointingHandCursor
      }
      background: Rectangle {
        x: slider.leftPadding
        y: slider.topPadding + slider.availableHeight / 2 - height / 2
        width: slider.availableWidth
        implicitHeight: 5
        height: 5; radius: 2.5
        color: Util.alpha(root.paletteForeground, 0.18)
        Rectangle {
          width: slider.handle.width / 2 + slider.visualPosition * (parent.width - slider.handle.width)
          height: parent.height
          radius: parent.radius
          color: root.paletteAccent
        }
      }
      handle: Rectangle {
        x: slider.leftPadding + slider.visualPosition * (slider.availableWidth - width)
        y: slider.topPadding + slider.availableHeight / 2 - height / 2
        implicitWidth: 20; implicitHeight: 20
        width: 20; height: 20; radius: 10
        color: slider.pressed ? "#eeeeee" : "#ffffff"
        border.color: "#26000000"
        border.width: 1
        Behavior on color { ColorAnimation { duration: 90 } }
        Rectangle {
          anchors.fill: parent
          anchors.margins: -1
          anchors.verticalCenterOffset: 1
          radius: 11
          color: "#18000000"
          z: -1
        }
        Rectangle {
          anchors.fill: parent
          anchors.margins: -4
          radius: 14
          color: "transparent"
          border.color: Util.alpha(root.paletteAccent, 0.5)
          border.width: 2
          visible: slider.activeFocus
        }
      }
    }
    Text {
      id: valueLabel
      width: 52
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      horizontalAlignment: Text.AlignRight
      text: control.valueText
      color: root.paletteAccent
      font.family: Style.font.family
      font.pixelSize: Style.font.bodySmall
    }
  }

  component UtilityButton: Rectangle {
    property string label: ""
    property string action: ""
    property bool selected: false
    property bool danger: false
    height: 34
    radius: 9
    color: utilityMouse.containsMouse
      ? (danger ? Util.alpha(Color.urgent, 0.18) : Util.alpha(root.paletteForeground, 0.13))
      : (selected ? Util.alpha(root.paletteAccent, 0.14) : Util.alpha(root.paletteForeground, 0.055))
    border.color: selected ? Util.alpha(root.paletteAccent, 0.60) : "transparent"
    border.width: 1
    Text {
      anchors.centerIn: parent
      text: label
      color: danger ? Color.urgent : root.paletteForeground
      font.family: Style.font.family
      font.pixelSize: Style.font.bodySmall
    }
    MouseArea {
      id: utilityMouse
      anchors.fill: parent
      hoverEnabled: true
      onClicked: {
        if (action === "appearanceTheme") root.appearanceModeAdjusted("theme")
        else if (action === "appearanceDefault") root.appearanceModeAdjusted("default")
        else if (action.indexOf("output:") === 0) root.screenshotOutputAdjusted(action.slice(7))
        else if (action === "closeSettings") root.opened = false
        else root.actionTriggered(action, root.itemData)
      }
    }
  }

  Item {
    id: dismissSurface
    anchors.fill: parent
    z: -1
    MouseArea { anchors.fill: parent; onClicked: root.opened = false }
  }
}
