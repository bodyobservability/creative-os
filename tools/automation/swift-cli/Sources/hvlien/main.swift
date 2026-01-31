import ArgumentParser

struct HVLIENCli: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "hvlien",
    subcommands: [
      // Core
      A0.self,
      Resolve.self,
      Plan.self,
      Apply.self,

      // UI tooling
      CaptureAnchor.self,
      ValidateAnchors.self,
      CalibrateRegions.self,
      RegionsSelect.self,

      // Safety + ops
      Doctor.self,

      // Voice + racks + sessions
      Voice.self,
      OCRDumpCmd.self,
      Rack.self,
      Session.self,

      // Sonic + governance
      Sonic.self,
      Station.self,
      Release.self,
      Pipeline.self,
      Report.self
    ]
  )
}

HVLIENCli.main()
