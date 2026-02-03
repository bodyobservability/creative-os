import Foundation

struct ReceiptSignal {
  let status: String
  let timestamp: Date?
}

struct ReceiptSignalReader {
  static func readStatus(path: String) -> ReceiptSignal? {
    guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
          let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
      return nil
    }
    let status = (obj["status"] as? String) ?? (obj["state"] as? String) ?? "unknown"
    let ts: Date?
    if let t = obj["timestamp"] as? String {
      ts = ISO8601DateFormatter().date(from: t)
    } else {
      ts = nil
    }
    return ReceiptSignal(status: status, timestamp: ts)
  }

  static func isStale(_ signal: ReceiptSignal?, maxAgeSeconds: TimeInterval) -> Bool {
    guard let sig = signal, let ts = sig.timestamp else { return false }
    return Date().timeIntervalSince(ts) > maxAgeSeconds
  }
}
