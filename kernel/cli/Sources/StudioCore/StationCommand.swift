import Foundation
import ArgumentParser

struct Station: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "station",
    abstract: "Station operations (v8.4).",
    subcommands: [Certify.self, Status.self]
  )

  struct Certify: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
      commandName: "certify",
      abstract: "Turnkey station certify: session compile + (optional auto sweep) + sonic certify."
    )

    @Option(name: .long, help: "Station profile id (default: bass_v1).")
    var profile: String = "bass_v1"

    @Option(name: .long, help: "Station profile path override.")
    var profilePath: String?

    @Option(name: .long, help: "Anchors pack override (passed to session compile).")
    var anchorsPack: String?

    @Flag(name: .long, help: "Run sweep --fix during session/voice phase where applicable.")
    var fix: Bool = false

    func run() async throws {
      _ = try await StationService.certify(config: .init(profile: profile,
                                                         profilePath: profilePath,
                                                         anchorsPack: anchorsPack,
                                                         fix: fix))
    }

  }
}
