# v9.5.5 wiring

1) Add ExportExtras to Assets subcommands:
subcommands: [
  ExportRacks.self,
  ExportPerformanceSet.self,
  ExportFinishingBays.self,
  ExportSerumBase.self,
  ExportExtras.self
]

2) Ensure AssetsPlanBuilder from v9.5.1 exists (ExportExtras reuses it).
