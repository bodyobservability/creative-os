import Foundation
enum ModalGuard {
  static let keywords = ["open","save","cancel","are you sure","missing","locate","authorization","plugin","replace","dont save","don’t save"]
  static func present(lines: [OCRLine]) -> Bool {
    let blob = StudioNormV1.normNameV1(lines.map(\.text).joined(separator: " "))
    for k in keywords {
      let nk = StudioNormV1.normNameV1(k)
      if nk != "__invalid__" && blob.contains(nk) { return true }
    }
    return false
  }
}
