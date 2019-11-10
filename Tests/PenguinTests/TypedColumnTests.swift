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

    func testSubsetting() {
        let c = PTypedColumn([1, 2, 3, 4, 5, 6])
        let set = PIndexSet(indices: [0, 3, 5], count: 6)
        let expected = PTypedColumn([1, 4, 6])
        XCTAssertEqual(c[set], expected)
    }

    func testScalarEquality() {
        let c = PTypedColumn([1, 2, 3, 1, 3, 4])
        XCTAssertEqual(c == 1, PIndexSet(indices: [0, 3], count: 6))
        XCTAssertEqual(c == 3, PIndexSet(indices: [2, 4], count: 6))

        let cStr = PTypedColumn(["a", "b", "c", "a", "xyz"])
        XCTAssertEqual(cStr == "a", PIndexSet(indices: [0, 3], count: 5))
    }

    func testScalarInequality() {
        let c = PTypedColumn([1, 2, 3, 1, 4, 2])
        XCTAssertEqual(c != 3,
                       PIndexSet([true, true, false, true, true, true], setCount: 5))
        XCTAssertEqual(c != 1,
                       PIndexSet([false, true, true, false, true, true], setCount: 4))
    }

    static var allTests = [
        ("testSum", testSum),
        ("testAvg", testAvg),
        ("testDescription", testDescription),
        ("testMinMax", testMinMax),
        ("testSubsetting", testSubsetting),
        ("testScalarEquality", testScalarEquality),
        ("testScalarInequality", testScalarInequality),
    ]
}
