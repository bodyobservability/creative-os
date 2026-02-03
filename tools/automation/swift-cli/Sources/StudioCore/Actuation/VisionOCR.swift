import Foundation
import Vision
import CoreGraphics

struct OCRLine {
  let text: String
  let confidence: Double
  let bbox: CGRect  // region-local TOP-LEFT coords
}

enum VisionOCR {
  static func recognizeLines(cgImage: CGImage) throws -> [OCRLine] {
    let req = VNRecognizeTextRequest()
    req.recognitionLevel = .fast
    req.usesLanguageCorrection = false
    req.minimumTextHeight = 0.02
    req.recognitionLanguages = ["en-US"]

    let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
    try handler.perform([req])

    guard let obs = req.results else { return [] }

    let imgW = CGFloat(cgImage.width)
    let imgH = CGFloat(cgImage.height)

    var out: [OCRLine] = []
    out.reserveCapacity(obs.count)

    for o in obs {
      guard let top = o.topCandidates(1).first else { continue }
      let bb = o.boundingBox
      let px = bb.origin.x * imgW
      let pyBottom = bb.origin.y * imgH
      let pw = bb.size.width * imgW
      let ph = bb.size.height * imgH
      let pyTop = imgH - pyBottom - ph
      out.append(OCRLine(text: top.string, confidence: Double(top.confidence),
                         bbox: CGRect(x: px, y: pyTop, width: pw, height: ph).integral))
    }

    out.sort { a, b in
      if a.bbox.minY != b.bbox.minY { return a.bbox.minY < b.bbox.minY }
      return a.bbox.minX < b.bbox.minX
    }
    return out
  }
}
