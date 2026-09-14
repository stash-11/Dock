import "."
import QtQuick

// Omarchy injects the host services into this entry point.
Item {
  id: root
  property var shell: null
  property var pluginRegistry: null
  property var manifest: null
  property var barWidgetRegistry: null
  property var service: null

  DockPanelBase {
    shell: root.shell
    pluginRegistry: root.pluginRegistry
    manifest: root.manifest
    dockHeight: 82
    bottomMargin: 10
    iconSize: 54
    slotWidth: 60
    slotSpacing: 6
    sidePadding: 16
    separatorWidth: 12
    hideDuration: 340
    showDuration: 300
  }
}
