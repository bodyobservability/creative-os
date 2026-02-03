import Foundation
import CoreGraphics

struct RegionsV1: Codable {
  struct Rect: Codable { let x: Int; let y: Int; let w: Int; let h: Int }
  let schemaVersion: Int
  let regions: [String: Rect]
  enum CodingKeys: String, CodingKey { case schemaVersion = "schema_version"; case regions }

  func cgRectTopLeft(_ id: String) -> CGRect? {
    guard let r = regions[id] else { return nil }
    return CGRect(x: r.x, y: r.y, width: r.w, height: r.h)
  }
}
