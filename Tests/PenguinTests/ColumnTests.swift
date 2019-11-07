import XCTest
@testable import Penguin

final class ColumnTests: XCTestCase {
    func testConversion() {
        let c: PColumn = PTypedColumn([1, 2, 3, 4])
        XCTAssertEqual(c.count, 4)
        XCTAssertEqual(c.asInt(), PTypedColumn<Int>([1, 2, 3, 4]))
    }

    static var allTests = [
        ("testConversion", testConversion),
    ]
}
