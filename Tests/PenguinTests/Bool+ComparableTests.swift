import XCTest
@testable import Penguin

final class BoolComparableTests: XCTestCase {

    func testComparison() {
        XCTAssert(false < true)
        XCTAssertFalse(true < true)
        XCTAssertFalse(false < false)
        XCTAssertFalse(true < false)
    }

    static var allTests = [
        ("testComparison", testComparison),
    ]
}
