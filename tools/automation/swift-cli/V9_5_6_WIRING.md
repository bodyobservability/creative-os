# v9.5.6 wiring (final TODO cleanup)

1) Add ExportAll to Assets subcommands:
subcommands: [
  ExportRacks.self,
  ExportPerformanceSet.self,
  ExportFinishingBays.self,
  ExportSerumBase.self,
  ExportExtras.self,
  ExportAll.self
]

2) Ensure all v9.5.x commands are present before using export-all.
