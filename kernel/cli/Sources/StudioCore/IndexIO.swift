import Foundation
import CryptoKit

enum IndexIO {
  static func sha256Hex(ofFile path: String) -> String? {
    guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)) else { return nil }
    let digest = SHA256.hash(data: data)
    return digest.map { String(format: "%02x", $0) }.joined()
  }

  static func fileSize(_ path: String) -> Int? {
    (try? FileManager.default.attributesOfItem(atPath: path)[.size] as? Int)
  }

  static func fileMTimeISO(_ path: String) -> String? {
    guard let dt = (try? FileManager.default.attributesOfItem(atPath: path)[.modificationDate] as? Date) ?? nil else { return nil }
    return ISO8601DateFormatter().string(from: dt)
  }

  static func ensureDir(_ path: String) throws {
    try FileManager.default.createDirectory(at: URL(fileURLWithPath: path, isDirectory: true), withIntermediateDirectories: true)
  }
}
