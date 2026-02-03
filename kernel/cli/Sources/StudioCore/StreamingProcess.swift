import Foundation

struct StreamingProcess {
  static func start(args: [String],
                    onChunk: @escaping (String) -> Void,
                    onExit: @escaping (Int32) -> Void) throws -> Process {
    let p = Process()
    p.executableURL = URL(fileURLWithPath: args[0])
    p.arguments = Array(args.dropFirst())

    let pipe = Pipe()
    p.standardOutput = pipe
    p.standardError = pipe

    let handle = pipe.fileHandleForReading
    handle.readabilityHandler = { h in
      let data = h.availableData
      guard !data.isEmpty else { return }
      if let s = String(data: data, encoding: .utf8) {
        onChunk(s)
      }
    }

    p.terminationHandler = { proc in
      handle.readabilityHandler = nil
      onExit(proc.terminationStatus)
    }

    try p.run()
    return p
  }
}
