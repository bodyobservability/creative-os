import Foundation

struct LegendRenderer {
  static func render(context: ShellContext) -> String {
    let specs = ActionCatalog.specs()
      .filter { $0.visible(context) }
      .sorted { $0.order < $1.order }
    let body = specs.map { $0.legend }.joined(separator: "   ")
    return "keys: \(body)"
  }
}
