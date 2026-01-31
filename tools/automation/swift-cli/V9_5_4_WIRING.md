# v9.5.4 wiring

Add ExportSerumBase to Assets subcommands:
subcommands: [ExportRacks.self, ExportPerformanceSet.self, ExportFinishingBays.self, ExportSerumBase.self]

Requires v4.3/v4.3.1 Serum anchors in your anchors pack:
- serum.window.signature
- serum.menu_preset
- serum.menu_save_preset

Requires macOS dialog anchor/region:
- macos.open_dialog.filename_field and/or os.file_dialog.filename_field
