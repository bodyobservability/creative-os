import Foundation
struct AnchorPackManifestV1: Codable {
  struct Targets: Codable {
    let os: String; let ableton: String; let theme: String; let uiScalePercent: Int?
    enum CodingKeys: String, CodingKey { case os, ableton, theme; case uiScalePercent = "ui_scale_percent" }
  }
  struct Anchor: Codable {
    let id: String; let imagePath: String; let maskPath: String?; let regionId: String; let minScore: Double?
    enum CodingKeys: String, CodingKey { case id; case imagePath = "image_path"; case maskPath = "mask_path"; case regionId = "region_id"; case minScore = "min_score" }
  }
  let schemaVersion: Int; let packId: String; let targets: Targets; let anchors: [Anchor]
  enum CodingKeys: String, CodingKey { case schemaVersion = "schema_version"; case packId = "pack_id"; case targets; case anchors }
}
