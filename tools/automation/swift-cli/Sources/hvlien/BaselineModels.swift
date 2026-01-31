import Foundation

struct BaselineIndexV1: Codable {
  struct Item: Codable {
    let rackId: String
    let profileId: String
    let macro: String
    let path: String
    let notes: String?
    enum CodingKeys: String, CodingKey { case rackId = "rack_id"; case profileId = "profile_id"; case macro; case path; case notes }
  }
  let schemaVersion: Int
  var items: [Item]
  enum CodingKeys: String, CodingKey { case schemaVersion = "schema_version"; case items }
}
