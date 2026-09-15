import QtQuick
import QtQuick.Effects
import qs.Commons

// Tint only bundled UI artwork; application icons retain their own colors.
Image {
  id: root
  property color iconColor: Color.foreground
  fillMode: Image.PreserveAspectFit
  layer.enabled: true
  layer.effect: MultiEffect {
    colorization: 1
    colorizationColor: root.iconColor
  }
}
