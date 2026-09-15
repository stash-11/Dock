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
    // Keep the entry point's original proportions while letting Appearance →
    // Dock Size scale the complete dock, including each app icon.
    dockHeight: Math.round(101 * dockScale)
    bottomMargin: 10
    iconSize: Math.round(50 * dockScale)
    slotWidth: Math.round(58 * dockScale)
    slotSpacing: Math.round(8 * dockScale)
    sidePadding: Math.round(18 * dockScale)
    separatorWidth: Math.round(14 * dockScale)
    hideDuration: 340
    showDuration: 300
  }
}
