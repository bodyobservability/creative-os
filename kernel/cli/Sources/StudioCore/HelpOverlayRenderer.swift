import Foundation

struct HelpOverlayRenderer {
  static func render(context: ShellContext) -> [String] {
    let displayContext = ShellContext(showLogs: context.showLogs,
                                      confirming: context.confirming,
                                      studioMode: context.studioMode,
                                      showAll: context.showAll,
                                      voiceMode: context.voiceMode,
                                      showHelp: false)
    let legend = LegendRenderer.render(context: displayContext).replacingOccurrences(of: "keys: ", with: "")
    return [
      "HELP",
      "",
      "Bar: A Anchors  S Sweep  I Index  F Files/Artifacts  R Ready",
      "Marks: ▣ pass  ▢ pending  ! warn  × fail",
      "",
      "Modes:",
      " SAFE   hides risky actions (exports/fix/repair/certify)",
      " GUIDED curated essentials (some risky)",
      " ALL    full surface area",
      "",
      "Keys:",
      " \(legend)",
      "",
      "Logs: \(RepoPaths.defaultRunsDir())/<id>/...",
      "Press ? to close"
    ]
  }
}
