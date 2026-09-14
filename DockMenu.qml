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
  property point requestedPosition: Qt.point(0, 0)
  property bool autoHideEnabled: true
  property string dockSide: "bottom"
  property real magnification: 1.85
  property real roundness: 1
  signal magnificationAdjusted(real value)
  signal roundnessAdjusted(real value)

  signal actionTriggered(string action, var itemData)

  visible: opened && itemData !== null
  color: "transparent"
  exclusionMode: ExclusionMode.Ignore
  WlrLayershell.layer: WlrLayer.Overlay
  WlrLayershell.namespace: "macos-dock-menu"
  anchors { top: true; bottom: true; left: true; right: true }
  mask: Region { item: dismissSurface }

  Rectangle {
    id: card
    x: Math.round((root.width - width) / 2)
    y: Math.round((root.height - height) / 2)
    width: 650
    height: 540
    radius: 22
    color: Util.alpha(Color.background, 0.97)
    border.color: Util.alpha(Color.foreground, 0.14)
    border.width: 1

    Column {
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
          color: Util.alpha(Color.foreground, 0.08)

          Image {
            id: appIcon
            anchors.centerIn: parent
            width: 48
            height: 48
            source: root.iconSource
            sourceSize: Qt.size(96, 96)
            fillMode: Image.PreserveAspectFit
            visible: status === Image.Ready
          }
          Text {
            anchors.centerIn: parent
            text: root.itemData && root.itemData.name ? String(root.itemData.name).charAt(0).toUpperCase() : "•"
            color: Color.foreground
            font.family: Style.font.family
            font.pixelSize: 24
            font.bold: true
            visible: !appIcon.visible
          }
        }

        Column {
          anchors.left: parent.left
          anchors.leftMargin: 72
          anchors.verticalCenter: parent.verticalCenter
          spacing: 3
          Text {
            text: root.itemData && root.itemData.name ? root.itemData.name : "Application"
            color: Color.foreground
            font.family: Style.font.family
            font.pixelSize: Style.font.title
            font.bold: true
          }
          Text {
            text: root.itemData && root.itemData.running ? "Running application" : "Pinned application"
            color: Util.alpha(Color.foreground, 0.52)
            font.family: Style.font.family
            font.pixelSize: Style.font.bodySmall
          }
        }

        Rectangle {
          width: 32
          height: 32
          anchors.right: parent.right
          radius: 16
          anchors.verticalCenter: parent.verticalCenter
          color: closeMouse.containsMouse ? Util.alpha(Color.foreground, 0.12) : "transparent"
          Text { anchors.centerIn: parent; text: "×"; color: Util.alpha(Color.foreground, 0.65); font.pixelSize: 22 }
          MouseArea { id: closeMouse; anchors.fill: parent; hoverEnabled: true; onClicked: root.opened = false }
        }
      }

      Rectangle { width: parent.width; height: 1; color: Util.alpha(Color.foreground, 0.10) }

      Text {
        text: "Application actions"
        color: Color.foreground
        font.family: Style.font.family
        font.pixelSize: Style.font.heading
        font.bold: true
      }

      Row {
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
            color: actionMouse.containsMouse ? Util.alpha(Color.accent, 0.16) : Util.alpha(Color.foreground, 0.065)
            border.color: actionMouse.containsMouse ? Util.alpha(Color.accent, 0.55) : "transparent"
            border.width: 1

            Column {
              anchors.centerIn: parent
              spacing: 8
              Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: modelData.glyph
                color: actionMouse.containsMouse ? Color.accent : Color.foreground
                font.pixelSize: 24
              }
              Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: modelData.label
                color: Color.foreground
                font.family: Style.font.family
                font.pixelSize: Style.font.body
              }
              Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: modelData.detail
                color: Util.alpha(Color.foreground, 0.45)
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

      Row {
        width: parent.width
        height: 38
        spacing: 8

        Text {
          text: "Dock Options"
          anchors.verticalCenter: parent.verticalCenter
          color: Util.alpha(Color.foreground, 0.52)
          font.family: Style.font.family
          font.pixelSize: Style.font.bodySmall
        }

        UtilityButton {
          label: root.autoHideEnabled ? "Hiding on" : "Hiding off"
          action: "toggleAutoHide"
          width: 104
        }
        UtilityButton { label: "Bottom"; action: "setSideBottom"; selected: root.dockSide === "bottom"; width: 78 }
        UtilityButton { label: "Left"; action: "setSideLeft"; selected: root.dockSide === "left"; width: 64 }
        UtilityButton { label: "Right"; action: "setSideRight"; selected: root.dockSide === "right"; width: 68 }

        Item { width: 1; height: 1 }

      }

      Column {
        width: parent.width
        spacing: 8
        Text {
          text: "Appearance"
          color: Color.foreground
          font.family: Style.font.family
          font.pixelSize: Style.font.heading
          font.bold: true
          height: 28
          verticalAlignment: Text.AlignVCenter
        }
        Rectangle { width: parent.width; height: 1; color: Util.alpha(Color.foreground, 0.08) }
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
      }
    }
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
      color: Color.foreground
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
      background: Rectangle {
        x: slider.leftPadding
        y: slider.topPadding + slider.availableHeight / 2 - height / 2
        width: slider.availableWidth
        implicitHeight: 5
        height: 5; radius: 2.5
        color: Util.alpha(Color.foreground, 0.18)
        Rectangle {
          width: slider.handle.width / 2 + slider.visualPosition * (parent.width - slider.handle.width)
          height: parent.height
          radius: parent.radius
          color: Color.accent
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
          border.color: Util.alpha(Color.accent, 0.5)
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
      color: Color.accent
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
      ? (danger ? Util.alpha(Color.urgent, 0.18) : Util.alpha(Color.foreground, 0.13))
      : (selected ? Util.alpha(Color.accent, 0.14) : Util.alpha(Color.foreground, 0.055))
    border.color: selected ? Util.alpha(Color.accent, 0.60) : "transparent"
    border.width: 1
    Text {
      anchors.centerIn: parent
      text: label
      color: danger ? Color.urgent : Color.foreground
      font.family: Style.font.family
      font.pixelSize: Style.font.bodySmall
    }
    MouseArea {
      id: utilityMouse
      anchors.fill: parent
      hoverEnabled: true
      onClicked: {
        root.actionTriggered(action, root.itemData)
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
