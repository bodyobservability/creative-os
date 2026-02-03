import Foundation

struct ActionRouter {
  static func route(_ key: InputKey, context: ShellContext) -> UserAction {
    if context.showHelp {
      switch key {
      case .help: return .toggleHelp
      case .quit: return .quit
      default: return .none
      }
    }
    switch key {
    case .quit: return .quit
    case .up: return .moveUp
    case .down: return .moveDown
    case .enter: return .runSelected
    case .runRecommended: return .runNext
    case .toggleVoiceMode: return .toggleVoice
    case .toggleStudioMode: return .toggleSafe
    case .toggleAll: return .toggleView
    case .toggleLogs: return .toggleLogs
    case .openRun: return .openRun
    case .openFailures: return .openFailures
    case .openReceipt: return .openReceipt
    case .openReport: return .openReport
    case .escape: return .back
    case .bottom: return .bottom
    case .refresh: return .refresh
    case .previewDriftPlan: return .previewDriftPlan
    case .readyVerify: return .readyVerify
    case .repairRun: return .repairRun
    case .selectNumber(let n): return .selectNumber(n)
    case .help: return .toggleHelp
    case .yes: return context.confirming ? .confirmYes : .none
    case .no: return context.confirming ? .confirmNo : .none
    case .none: return .none
    }
  }
}
