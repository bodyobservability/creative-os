import Foundation

struct ShellContext {
  let showLogs: Bool
  let confirming: Bool
  let studioMode: Bool
  let showAll: Bool
  let voiceMode: Bool
  let showHelp: Bool
}

enum UserAction {
  case none
  case quit
  case moveUp
  case moveDown
  case runSelected
  case runNext
  case toggleVoice
  case toggleSafe
  case toggleView
  case toggleLogs
  case openRun
  case openFailures
  case openReceipt
  case openReport
  case back
  case bottom
  case refresh
  case previewDriftPlan
  case readyVerify
  case repairRun
  case selectNumber(Int)
  case confirmYes
  case confirmNo
  case toggleHelp
}

struct ActionSpec {
  let id: String
  let legend: String
  let help: String
  let order: Int
  let visible: (ShellContext) -> Bool
}
