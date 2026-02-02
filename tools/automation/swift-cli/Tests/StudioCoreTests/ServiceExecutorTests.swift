import XCTest
@testable import StudioCore

final class ServiceExecutorTests: XCTestCase {
  func testUnsupportedActionThrows() async {
    let config = CreativeOS.Effect(id: "config",
                                   kind: .config,
                                   target: "{}",
                                   description: nil)
    let step = CreativeOS.PlanStep(id: "unsupported_action",
                                   agent: "test",
                                   type: .automated,
                                   description: "Unsupported action",
                                   effects: [config],
                                   idempotent: true,
                                   manualReason: nil,
                                   actionRef: .init(id: "unknown.action", kind: .setup, description: nil))

    do {
      _ = try await ServiceExecutor.execute(step: step)
      XCTFail("Expected unsupportedAction error")
    } catch let error as ServiceExecutor.ExecutionError {
      switch error {
      case .unsupportedAction(let actionId):
        XCTAssertEqual(actionId, "unknown.action")
      case .missingConfig:
        XCTFail("Expected unsupportedAction, got missingConfig")
      }
    } catch {
      XCTFail("Unexpected error: \(error)")
    }
  }
}
