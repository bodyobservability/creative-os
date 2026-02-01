import ArgumentParser
import Foundation

@main
@available(macOS 10.15, macCatalyst 13, iOS 13, tvOS 13, watchOS 6, *)
struct HVLIENCli: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "hvlien",
    subcommands: [
      // Core
      A0.self,
      Resolve.self,
      Index.self,
      Drift.self,
      Plan.self,
      Apply.self,

      // UI tooling
      CaptureAnchor.self,
      ValidateAnchors.self,
      CalibrateRegions.self,
      RegionsSelect.self,

      // Safety + ops
      Doctor.self,
      MidiList.self,

      // Voice + racks + sessions
      Voice.self,
      VRL.self,
      UI.self,
      OCRDumpCmd.self,
      Rack.self,
      Session.self,
      Assets.self,

      // Sonic + governance
      Sonic.self,
      Ready.self,
      Repair.self,
      Station.self,
      Release.self,
      Pipeline.self,
      Report.self
    ]
  )
}
