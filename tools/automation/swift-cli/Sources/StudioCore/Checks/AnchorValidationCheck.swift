import Foundation
struct AnchorValidationCheck: DubSweeperCheck {
  let id = "anchors_validation"
  func run(context: DubSweeperContext) async throws -> CheckResult {
    guard let pack = context.anchorsPackPath else { return .skip(id, details:["reason":"no anchors pack provided"], artifacts: []) }
    #if OPENCV_ENABLED
    return .pass(id, details:["pack":pack,"note":"Run validate-anchors for detailed scores"], artifacts: [])
    #else
    if context.allowOcrFallback { return .skip(id, details:["reason":"OpenCV not enabled; OCR fallback allowed","pack":pack], artifacts: []) }
    return .fail(id, details:["reason":"OpenCV not enabled; build Xcode OpenCV version or pass --allow-ocr-fallback","pack":pack], artifacts: [])
    #endif
  }
}
