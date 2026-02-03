import Foundation

struct ActionCatalog {
  static func specs() -> [ActionSpec] {
    [
      .init(id: "nav", legend: "↑↓ select", help: "Move selection", order: 10, visible: { !$0.showLogs && !$0.showHelp }),
      .init(id: "scroll", legend: "↑↓ scroll", help: "Scroll logs", order: 11, visible: { $0.showLogs && !$0.showHelp }),
      .init(id: "enter", legend: "ENTER run", help: "Run selected action", order: 20, visible: { !$0.showLogs && !$0.showHelp }),
      .init(id: "space", legend: "SPACE next", help: "Run recommended action", order: 21, visible: { !$0.showLogs && !$0.showHelp }),
      .init(id: "safe", legend: "s SAFE/GUIDED", help: "Toggle SAFE/GUIDED", order: 30, visible: { !$0.showHelp }),
      .init(id: "view", legend: "a GUIDED/ALL", help: "Toggle GUIDED/ALL", order: 31, visible: { !$0.studioMode && !$0.showHelp }),
      .init(id: "voice", legend: "v voice", help: "Toggle voice mode", order: 32, visible: { !$0.showHelp }),
      .init(id: "logs", legend: "l logs", help: "Toggle logs pane", order: 33, visible: { !$0.showHelp }),
      .init(id: "bottom", legend: "0 bottom", help: "Jump to bottom of logs", order: 34, visible: { $0.showLogs && !$0.showHelp }),
      .init(id: "open_run", legend: "o run", help: "Open last run folder", order: 40, visible: { !$0.showHelp }),
      .init(id: "open_fail", legend: "f fail", help: "Open failures folder", order: 41, visible: { !$0.showHelp }),
      .init(id: "open_receipt", legend: "r receipt", help: "Open last receipt", order: 42, visible: { !$0.showHelp }),
      .init(id: "back", legend: "ESC back", help: "Back to actions", order: 50, visible: { $0.showLogs && !$0.showHelp }),
      .init(id: "help", legend: "? help", help: "Toggle help", order: 90, visible: { _ in true }),
      .init(id: "quit", legend: "q quit", help: "Quit shell", order: 99, visible: { !$0.showHelp }),
      .init(id: "confirm", legend: "y/n confirm", help: "Confirm or cancel", order: 5, visible: { $0.confirming && !$0.showHelp })
    ]
  }
}
