import ArgumentParser
@main struct HVLIENCli: AsyncParsableCommand { static let configuration = CommandConfiguration(commandName: "hvlien", subcommands: [A0.self, Resolve.self]) }
