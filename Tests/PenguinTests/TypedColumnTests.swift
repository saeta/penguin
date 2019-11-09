import XCTest
@testable import Penguin

final class TypedColumnTests: XCTestCase {
    func testSum() {
        let c = PTypedColumn([1, 2, 3, 4])
        XCTAssertEqual(c.sum(), 10)
        XCTAssertEqual(c.map { $0 * 2 }.sum(), 20)

        let c2 = PTypedColumn([1.0, 2.0, 3.0, 4.0])
        XCTAssertEqual(c2.sum(), 10)
        XCTAssertEqual(c2.map { $0 * 2 }.sum(), 20)
    }

    func testAvg() {
        let c = PTypedColumn([2, 3, 4])
        XCTAssertEqual(c.avg(), 3.0)
    }

    func testDescription() {
        let c = PTypedColumn([1, 5, 10])
        XCTAssertEqual(c.description, """
        i	Int
        0	1
        1	5
        2	10

        """)
    }

    func testMinMax() {
        let cInt = PTypedColumn([1, 4, 10, 18, -3])
        XCTAssertEqual(cInt.min(), -3)
        XCTAssertEqual(cInt.max(), 18)

        let cStr = PTypedColumn(["a", "xyz", "foo"])
        XCTAssertEqual(cStr.min(), "a")
        XCTAssertEqual(cStr.max(), "xyz")
    }

    static var allTests = [
        ("testSum", testSum),
        ("testAvg", testAvg),
        ("testDescription", testDescription),
    ]
}
