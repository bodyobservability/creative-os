import Foundation

struct ActionHandler {
  let id: String
  let execute: (ServiceExecutor.ConfigBag, CreativeOS.PlanStep) async throws -> Int32?
}

struct ActionHandlerRegistry {
  private var handlers: [String: ActionHandler] = [:]

  mutating func register(_ handler: ActionHandler) {
    handlers[handler.id] = handler
  }

  func handler(for id: String) -> ActionHandler? {
    handlers[id]
  }

  var ids: Set<String> {
    Set(handlers.keys)
  }
}
