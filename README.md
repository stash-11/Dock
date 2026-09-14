# My Dock

A macOS-inspired opaque restyle of the reference Omarchy dock. All application,
pinning, ordering, icon picker, auto-hide, side placement, Downloads,
Trash and app-switcher functionality is retained.

## Appearance

- Opaque rounded surface matching the active Omarchy theme.
- Fixed resting dock width during magnification; icons can extend beyond the surface.
- 1.85× magnification with a 150px influence radius and smooth 120ms easing.
- Working hover lift, three-stage launch bounce and pressed-icon feedback.
- Neutral running dots and expanded pointer coverage for enlarged icons.
- 54px resting icons, 82px surface, 10px desktop-edge margin.

Edit `DockModel.js` for magnification and `DockPanel.qml` for dimensions.
Keep slot size, spacing and padding in these files synchronized.

## Use

This is an **Omarchy plugin**, with `DockPanel.qml` as its entry point, rather
than a standalone `shell.qml`. It needs the host's `qs.Commons` and `qs.Ui`.
The manifest retains `macos.dock` so existing settings, pins and IPC commands
remain compatible. Use it as a replacement for that plugin, not alongside it.

To install manually, back up any existing `~/.config/omarchy/plugins/macos.dock`
directory first, copy this folder there, then run `omarchy plugin enable macos.dock`.
The workspace copy has not been installed or enabled automatically.

The dock surface uses the active theme background at full opacity. It does not reproduce Apple's
proprietary refraction or add compositor-wide blur. Window minimization effects
belong to the compositor and are not changed by this plugin.

## Validation

Run `bash tests/run.sh`. The inherited insertion test uses a slot-relative
coordinate to account for the larger magnification.

See `README.reference.md` for inherited feature documentation and commands.
The original license and attribution are preserved in `LICENSE` and the manifest.

Hover shows application names only; window thumbnail previews are disabled.
