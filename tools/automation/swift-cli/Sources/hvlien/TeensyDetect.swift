import Foundation
enum TeensyDetect {
  static func autoDetectDevicePath() -> String? {
    let items = (try? FileManager.default.contentsOfDirectory(atPath: "/dev")) ?? []
    let m1 = items.filter { $0.hasPrefix("cu.usbmodem") }.sorted()
    if let f = m1.first { return "/dev/\(f)" }
    let m2 = items.filter { $0.hasPrefix("cu.usbserial") }.sorted()
    if let f = m2.first { return "/dev/\(f)" }
    return nil
  }
}
