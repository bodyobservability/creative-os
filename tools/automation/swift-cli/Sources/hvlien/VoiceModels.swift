import Foundation

enum VoiceStepKind: String {
  case section
  case say
  case dictate
  case map
  case renameMacros = "rename_macros"
  case verify
}

struct VoiceScript: Codable {
  let schemaVersion: Int
  let name: String
  let goal: String?
  let assumptions: [String: AnyCodable]?
  let steps: [AnyCodable]

  enum CodingKeys: String, CodingKey {
    case schemaVersion = "schema_version"
    case name, goal, assumptions, steps
  }
}

struct MacroABI: Codable {
  struct Macro: Codable {
    let id: String
    let name: String
    let range: [Double]?
    let intent: String?
  }
  let schemaVersion: Int
  let name: String
  let description: String?
  let macros: [Macro]

  enum CodingKeys: String, CodingKey {
    case schemaVersion = "schema_version"
    case name, description, macros
  }
}
