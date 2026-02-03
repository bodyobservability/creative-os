import Foundation

struct ToastManager {
  enum Level: Int, Comparable {
    case info = 0
    case success = 1
    case blocked = 2

    static func < (lhs: Level, rhs: Level) -> Bool { lhs.rawValue < rhs.rawValue }
  }

  struct Toast: Equatable {
    let level: Level
    let message: String
    let createdAt: Date
    let expiresAt: Date
    let key: String
  }

  private(set) var current: Toast? = nil
  private var lastShown: [String: Date] = [:]
  var throttleWindow: TimeInterval = 3.0

  mutating func tick(now: Date = Date()) {
    if let t = current, now >= t.expiresAt {
      current = nil
    }
  }

  var currentText: String? {
    guard let t = current else { return nil }
    let prefix: String
    switch t.level {
    case .info: prefix = "•"
    case .success: prefix = "✓"
    case .blocked: prefix = "!"
    }
    return "\(prefix) \(t.message)"
  }

  mutating func show(_ message: String, level: Level, key: String, ttl: TimeInterval, now: Date = Date()) {
    if let last = lastShown[key], now.timeIntervalSince(last) < throttleWindow { return }
    if let cur = current, now < cur.expiresAt, level < cur.level { return }

    let toast = Toast(level: level,
                      message: message,
                      createdAt: now,
                      expiresAt: now.addingTimeInterval(ttl),
                      key: key)
    current = toast
    lastShown[key] = now
  }

  mutating func info(_ msg: String, key: String, ttl: TimeInterval = 1.5) {
    show(msg, level: .info, key: key, ttl: ttl)
  }

  mutating func success(_ msg: String, key: String, ttl: TimeInterval = 1.2) {
    show(msg, level: .success, key: key, ttl: ttl)
  }

  mutating func blocked(_ msg: String, key: String, ttl: TimeInterval = 2.5) {
    show(msg, level: .blocked, key: key, ttl: ttl)
  }
}
