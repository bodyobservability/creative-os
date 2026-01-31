# v9.5.3 wiring

1) Add ExportFinishingBays to Assets subcommands:
   subcommands: [ExportRacks.self, ExportPerformanceSet.self, ExportFinishingBays.self]

2) Ensure PerformanceSetPlanBuilder from v9.5.2 is present (FinishingBaysPlanBuilder reuses it).
