import XCTest
@testable import StudioCore

final class CreativeOSActionCatalogTests: XCTestCase {
  func testCatalogCoversServiceExecutorActions() {
    let catalogIds = Set(CreativeOSActionCatalog.all.map { $0.id })
    let missing = ServiceExecutor.supportedActionIds.subtracting(catalogIds)
    XCTAssertTrue(missing.isEmpty, "Missing catalog entries for: \(missing)")
  }

  func testStateSetupAllowlistIsSupported() {
    let allowlist = CreativeOSActionCatalog.stateSetupAllowlist
    XCTAssertFalse(allowlist.isEmpty)
    XCTAssertTrue(allowlist.isSubset(of: ServiceExecutor.supportedActionIds))
  }
}
