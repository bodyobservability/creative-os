import Foundation

enum FinishingBaysPlanBuilder {
  static func buildSaveAsPlan(targetDir: String, fileName: String) -> [String: Any] {
    return PerformanceSetPlanBuilder.buildPerformanceSetExportPlan(targetDir: targetDir, fileName: fileName)
  }
}
