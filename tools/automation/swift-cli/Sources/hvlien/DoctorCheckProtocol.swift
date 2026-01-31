import Foundation

enum ModalTestMode: String, Codable { case detect, active }

struct DoctorContext {
  let runId: String
  let runDir: URL
  let artifactsDir: URL
  let regionsPath: String
  let anchorsPackPath: String?
  let modalTestMode: ModalTestMode
  let requiredControllers: [String]
  let allowOcrFallback: Bool
  let nowISO8601: () -> String
  init(runId: String, runDir: URL, artifactsDir: URL, regionsPath: String, anchorsPackPath: String?,
       modalTestMode: ModalTestMode, requiredControllers: [String], allowOcrFallback: Bool,
       nowISO8601: @escaping () -> String = { ISO8601DateFormatter().string(from: Date()) }) {
    self.runId = runId; self.runDir = runDir; self.artifactsDir = artifactsDir
    self.regionsPath = regionsPath; self.anchorsPackPath = anchorsPackPath
    self.modalTestMode = modalTestMode; self.requiredControllers = requiredControllers
    self.allowOcrFallback = allowOcrFallback; self.nowISO8601 = nowISO8601
  }
}

struct CheckResult {
  let id: String
  let status: DoctorStatus
  let details: [String: String]
  let artifacts: [String]
  static func pass(_ id: String, details: [String: String] = [:], artifacts: [String] = []) -> CheckResult { .init(id: id, status: .pass, details: details, artifacts: artifacts) }
  static func fail(_ id: String, details: [String: String] = [:], artifacts: [String] = []) -> CheckResult { .init(id: id, status: .fail, details: details, artifacts: artifacts) }
  static func skip(_ id: String, details: [String: String] = [:], artifacts: [String] = []) -> CheckResult { .init(id: id, status: .skip, details: details, artifacts: artifacts) }
}

protocol DoctorCheck {
  var id: String { get }
  func run(context: DoctorContext) async throws -> CheckResult
}
