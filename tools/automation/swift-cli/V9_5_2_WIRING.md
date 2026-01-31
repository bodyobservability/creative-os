# v9.5.2 wiring

Add ExportPerformanceSet to Assets subcommands.

Update `Assets` configuration:
subcommands: [ExportRacks.self, ExportPerformanceSet.self]

Also ensure `Assets.self` is wired in CliMain.swift/main.swift.
