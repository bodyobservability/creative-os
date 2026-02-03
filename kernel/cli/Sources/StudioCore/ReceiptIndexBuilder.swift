import Foundation
#if canImport(CryptoKit)
import CryptoKit
#endif

enum ReceiptIndexBuilder {
  static func build(runsDir: String = RepoPaths.defaultRunsDir()) -> ReceiptIndexV1 {
    let ts = ISO8601DateFormatter().string(from: Date())
    var receipts: [ReceiptIndexV1.Receipt] = []
    let fm = FileManager.default
    guard fm.fileExists(atPath: runsDir) else {
      return ReceiptIndexV1(schemaVersion: 1, generatedAt: ts, receipts: [])
    }
    // scan \(RepoPaths.defaultRunsDir())/<run_id> for *receipt*.json
    if let runIds = try? fm.contentsOfDirectory(atPath: runsDir) {
      for rid in runIds {
        let rpath = URL(fileURLWithPath: runsDir).appendingPathComponent(rid, isDirectory: true).path
        guard fm.fileExists(atPath: rpath) else { continue }
        if let files = try? fm.contentsOfDirectory(atPath: rpath) {
          for f in files where f.contains("receipt") && f.hasSuffix(".json") {
            let full = URL(fileURLWithPath: rpath).appendingPathComponent(f).path
            if let rec = parseReceipt(path: full, runId: rid) {
              receipts.append(rec)
            }
          }
        }
      }
    }
    receipts.sort { $0.path < $1.path }
    return ReceiptIndexV1(schemaVersion: 1, generatedAt: ts, receipts: receipts)
  }

  private static func parseReceipt(path: String, runId: String) -> ReceiptIndexV1.Receipt? {
    guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
          let obj = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else { return nil }
    let status = obj["status"] as? String
    let ts = obj["timestamp"] as? String ?? obj["generated_at"] as? String ?? ISO8601DateFormatter().string(from: Date())
    let kind = obj["job"] as? String ?? (obj["schema_version"] != nil ? "receipt" : "unknown")
    let receiptId = sha1Hex(kind + "|" + path)
    return ReceiptIndexV1.Receipt(receiptId: receiptId, kind: kind, path: path, runId: runId, timestamp: ts, status: status)
  }

  // Minimal SHA1 helper (not cryptographic requirements; just stable ids)
  private static func sha1Hex(_ s: String) -> String {
    // Use SHA256 and truncate for simplicity
    if let data = s.data(using: .utf8) {
      #if canImport(CryptoKit)
      let digest = SHA256.hash(data: data)
      return digest.map { String(format: "%02x", $0) }.joined().prefix(40).description
      #else
      return String(s.hashValue)
      #endif
    }
    return String(s.hashValue)
  }
}
