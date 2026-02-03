import Foundation

struct IndexService {
  struct BuildConfig {
    let repoVersion: String
    let outDir: String
    let runsDir: String
  }

  struct BuildResult {
    let receiptPath: String
    let artifactPath: String
  }

  static func build(config: BuildConfig) throws -> BuildResult {
    try IndexIO.ensureDir(config.outDir)

    let receiptIndex = ReceiptIndexBuilder.build(runsDir: config.runsDir)
    let expected = try ExpectedArtifactsParser.parseAll()
    let artifactIndex = ArtifactIndexBuilder.build(repoVersion: config.repoVersion,
                                                   expected: expected,
                                                   receiptIndex: receiptIndex)

    let receiptPath = URL(fileURLWithPath: config.outDir).appendingPathComponent("receipt_index.v1.json")
    let artifactPath = URL(fileURLWithPath: config.outDir).appendingPathComponent("artifact_index.v1.json")

    try JSONIO.save(receiptIndex, to: receiptPath)
    try JSONIO.save(artifactIndex, to: artifactPath)

    return BuildResult(receiptPath: receiptPath.path, artifactPath: artifactPath.path)
  }

  struct StatusResult {
    let total: Int
    let counts: [String: Int]
  }

  static func status(path: String) throws -> StatusResult {
    let idx = try JSONIO.load(ArtifactIndexV1.self, from: URL(fileURLWithPath: path))
    var counts: [String: Int] = [:]
    for a in idx.artifacts {
      counts[a.status.state, default: 0] += 1
    }
    return StatusResult(total: idx.artifacts.count, counts: counts)
  }
}
