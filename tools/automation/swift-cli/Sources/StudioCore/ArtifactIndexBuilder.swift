import Foundation
import CryptoKit

enum ArtifactIndexBuilder {

  static func build(repoVersion: String,
                    expected: [ExpectedArtifactV1],
                    receiptIndex: ReceiptIndexV1,
                    staleWarnAfterS: Int = 24*3600,
                    staleFailAfterS: Int = 7*24*3600) -> ArtifactIndexV1 {
    let ts = ISO8601DateFormatter().string(from: Date())
    var artifacts: [ArtifactIndexV1.Artifact] = []

    for e in expected {
      if e.path.hasSuffix("/") {
        artifacts.append(makeDirMarker(kind: e.kind, dirPath: e.path, job: e.job))
      } else {
        artifacts.append(makeFileArtifact(kind: e.kind,
                                          path: e.path,
                                          expectedMinBytes: e.minBytes,
                                          expectedWarnBytes: e.warnBytes,
                                          job: e.job,
                                          receiptIndex: receiptIndex,
                                          staleWarnAfterS: staleWarnAfterS,
                                          staleFailAfterS: staleFailAfterS))
      }
    }

    // De-dup by artifact_id (keep first)
    var seen: Set<String> = []
    artifacts = artifacts.filter { a in
      if seen.contains(a.artifactId) { return false }
      seen.insert(a.artifactId)
      return true
    }.sorted { $0.path < $1.path }

    return ArtifactIndexV1(schemaVersion: 1, generatedAt: ts, repoVersion: repoVersion, artifacts: artifacts)
  }

  private static func makeDirMarker(kind: String, dirPath: String, job: String?) -> ArtifactIndexV1.Artifact {
    let id = stableId(kind: kind, path: dirPath)
    let exists = FileManager.default.fileExists(atPath: dirPath)
    let status = ArtifactIndexV1.Status(state: exists ? "unknown" : "missing",
                                        reason: exists ? "directory_marker" : "expected_directory_missing")
    return ArtifactIndexV1.Artifact(artifactId: id, kind: kind, path: dirPath, exists: exists, bytes: nil, sha256: nil, mtime: nil, export: nil, dependencies: nil, status: status)
  }

  private static func makeFileArtifact(kind: String,
                                       path: String,
                                       expectedMinBytes: Int?,
                                       expectedWarnBytes: Int?,
                                       job: String?,
                                       receiptIndex: ReceiptIndexV1,
                                       staleWarnAfterS: Int,
                                       staleFailAfterS: Int) -> ArtifactIndexV1.Artifact {
    let id = stableId(kind: kind, path: path)
    let exists = FileManager.default.fileExists(atPath: path)
    let bytes = IndexIO.fileSize(path)
    let mtimeIso = IndexIO.fileMTimeISO(path)
    let sha = exists ? IndexIO.sha256Hex(ofFile: path) : nil

    let exp = findExportProvenance(path: path, job: job, receiptIndex: receiptIndex)
    let (state, reason) = classify(exists: exists,
                                   bytes: bytes,
                                   expectedMin: expectedMinBytes,
                                   mtimeIso: mtimeIso,
                                   job: job,
                                   receiptIndex: receiptIndex,
                                   staleWarnAfterS: staleWarnAfterS,
                                   staleFailAfterS: staleFailAfterS)

    let status = ArtifactIndexV1.Status(state: state, reason: reason)
    return ArtifactIndexV1.Artifact(artifactId: id, kind: kind, path: path, exists: exists, bytes: bytes, sha256: sha, mtime: mtimeIso, export: exp, dependencies: nil, status: status)
  }

  private static func classify(exists: Bool,
                               bytes: Int?,
                               expectedMin: Int?,
                               mtimeIso: String?,
                               job: String?,
                               receiptIndex: ReceiptIndexV1,
                               staleWarnAfterS: Int,
                               staleFailAfterS: Int) -> (String, String) {
    if !exists { return ("missing", "expected_file_missing") }
    if let minB = expectedMin, let b = bytes, b < minB { return ("placeholder", "below_min_bytes") }

    // stale detection: if there is a newer receipt for the same job, and file mtime is older beyond budgets.
    guard let job = job, let mIso = mtimeIso, let mTime = ISO8601DateFormatter().date(from: mIso) else {
      return ("current", "meets_min_bytes")
    }

    let latestReceiptTime = latestReceiptTimestamp(forJob: job, receiptIndex: receiptIndex)
    guard let lr = latestReceiptTime else { return ("current", "meets_min_bytes") }

    let delta = Int(lr.timeIntervalSince(mTime))
    if delta <= 0 { return ("current", "up_to_date") }
    if delta >= staleFailAfterS { return ("stale", "older_than_latest_receipt_fail") }
    if delta >= staleWarnAfterS { return ("stale", "older_than_latest_receipt_warn") }
    return ("current", "recent_within_budget")
  }

  private static func latestReceiptTimestamp(forJob job: String, receiptIndex: ReceiptIndexV1) -> Date? {
    let fmt = ISO8601DateFormatter()
    var latest: Date? = nil
    for r in receiptIndex.receipts where r.kind == job {
      if let d = fmt.date(from: r.timestamp) {
        if latest == nil || d > latest! { latest = d }
      }
    }
    return latest
  }

  private static func findExportProvenance(path: String, job: String?, receiptIndex: ReceiptIndexV1) -> ArtifactIndexV1.Export? {
    guard let job = job else { return nil }
    for r in receiptIndex.receipts where r.kind == job {
      if let data = try? Data(contentsOf: URL(fileURLWithPath: r.path)),
         let s = String(data: data, encoding: .utf8),
         s.contains(path) {
        return ArtifactIndexV1.Export(job: job, runId: r.runId, receiptPath: r.path, exportedAt: r.timestamp)
      }
    }
    return nil
  }

  private static func stableId(kind: String, path: String) -> String {
    let input = (kind + "|" + path).data(using: .utf8) ?? Data()
    let digest = SHA256.hash(data: input)
    return digest.map { String(format: "%02x", $0) }.joined().prefix(32).description
  }
}
