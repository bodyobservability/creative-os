import Foundation

struct StationStateSignalV1: Codable {
  let id: String
  let value: String?
  let weight: Double
  let contribution: Contribution

  struct Contribution: Codable {
    let stateVotes: [String: Double]
    let confidenceDelta: Double

    enum CodingKeys: String, CodingKey {
      case stateVotes = "state_votes"
      case confidenceDelta = "confidence_delta"
    }
  }
}

struct StationStateReportV1: Codable {
  let schemaVersion: Int
  let runId: String
  let timestamp: String
  let status: String
  let confidence: Double
  let stationState: String
  let activeApp: ActiveApp?
  let ableton: AbletonInfo?
  let signals: [StationStateSignalV1]
  let evidence: [String: String?]
  let reasons: [String]

  enum CodingKeys: String, CodingKey {
    case schemaVersion = "schema_version"
    case runId = "run_id"
    case timestamp
    case status
    case confidence
    case stationState = "station_state"
    case activeApp = "active_app"
    case ableton
    case signals
    case evidence
    case reasons
  }

  struct ActiveApp: Codable {
    let bundleId: String
    let name: String
    enum CodingKeys: String, CodingKey { case bundleId = "bundle_id"; case name }
  }

  struct AbletonInfo: Codable {
    let detected: Bool
    let version: String?
    let frontmost: Bool?
    let setTitle: String?
    let setPathHint: String?
    let transport: Transport?
    let ui: UIInfo?

    enum CodingKeys: String, CodingKey {
      case detected, version, frontmost
      case setTitle = "set_title"
      case setPathHint = "set_path_hint"
      case transport, ui
    }

    struct Transport: Codable { let playing: Bool?; let recording: Bool? }
    struct UIInfo: Codable {
      let modalDetected: Bool?
      let saveSheetDetected: Bool?
      enum CodingKeys: String, CodingKey {
        case modalDetected = "modal_detected"
        case saveSheetDetected = "save_sheet_detected"
      }
    }
  }
}
