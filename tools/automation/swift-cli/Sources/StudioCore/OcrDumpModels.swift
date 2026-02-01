import Foundation
import CoreGraphics

struct OCRDumpLine: Codable {
  let text: String
  let confidence: Double
  let bbox: BBox
  struct BBox: Codable { let x: Double; let y: Double; let w: Double; let h: Double }
  init(_ ln: OCRLine) {
    text = ln.text; confidence = ln.confidence
    bbox = .init(x: ln.bbox.origin.x, y: ln.bbox.origin.y, w: ln.bbox.size.width, h: ln.bbox.size.height)
  }
}

struct OCRDump: Codable {
  let regionId: String
  let target: String?
  let matchMode: String?
  let minConf: Double?
  let lines: [OCRDumpLine]
}
