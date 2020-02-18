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
        // TODO: Add nils!
    }

    func testAvg() {
        let c = PTypedColumn([2, 3, 4])
        XCTAssertEqual(c.avg(), 3.0)
    }

    func testMap() {
        let c = PTypedColumn([1, 2, nil, 4])
        let c2 = c.map { $0 * 2 }

        let expected = PTypedColumn([2, 4, nil, 8])
        XCTAssertEqual(c2, expected)
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

    func testMinMaxOptionals() {
        let c1 = PTypedColumn([nil, 1, 2, 3, 4])
        XCTAssertEqual(1, c1.min())
        XCTAssertEqual(4, c1.max())

        let c2 = PTypedColumn([3.14159, nil, 2.7182818])
        XCTAssertEqual(2.7182818, c2.min())
        XCTAssertEqual(3.14159, c2.max())
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

    func testScalarComparisons() {
        let c = PTypedColumn([1, 2, 3])
        XCTAssertEqual(c < 2, PIndexSet([true, false, false], setCount: 1))
        XCTAssertEqual(c < 3, PIndexSet([true, true, false], setCount: 2))
        XCTAssertEqual(c >= -100, PIndexSet([true, true, true], setCount: 3))
        XCTAssertEqual(c <= -1, PIndexSet([false, false, false], setCount: 0))

        let cStr = PTypedColumn(["a", "b", "cat"])
        XCTAssertEqual(cStr < "bbbbb", PIndexSet([true, true, false], setCount: 2))
    }

    func testArbitraryFilter() {
        let c = PTypedColumn(["a", "aa", "b", "bb", "c"])
        XCTAssertEqual(c.filter { $0.count == 1 }, PIndexSet([true, false, true, false, true], setCount: 3))
    }

    func testElementSubscript() {
        var c = PTypedColumn(["a", "aa", "b"])
        XCTAssertEqual(c[1], "aa")
        c[2] = "bb"
        XCTAssertEqual(c, PTypedColumn(["a", "aa", "bb"]))
    }

    func testOptionalColumn() {
        let c = PTypedColumn([nil, 1, nil, 3])
        XCTAssertEqual(c.nils, PIndexSet([true, false, true, false], setCount: 2))
        XCTAssertEqual(c.nonNils, PIndexSet([false, true, false, true], setCount: 2))
    }

    func testSubscriptGatherWithNils() {
        let c = PTypedColumn([nil, 1, nil, 3])
        let indexSet = PIndexSet([true, true, false, false], setCount: 2)
        let expected = PTypedColumn([nil, 1])
        XCTAssertEqual(c[indexSet], expected)
    }

    func testOptionalSubscript() {
        var c = PTypedColumn([nil, 1, nil, 3])
        XCTAssertEqual(c[0], nil)
        XCTAssertEqual(c[1], 1)
        XCTAssertEqual(c[2], nil)
        XCTAssertEqual(c[3], 3)

        c[2] = 2
        XCTAssertEqual(c[2], 2)

        c[3] = nil
        XCTAssertEqual(c, PTypedColumn([nil, 1, 2, nil]))
    }

    func testScalarComparasonsWithNils() {
        let c = PTypedColumn([nil, 1, nil, 3, 1])
        XCTAssertEqual(c == 1, PIndexSet([false, true, false, false, true], setCount: 2))
        XCTAssertEqual(c != 1, PIndexSet([false, false, false, true, false], setCount: 1))
        XCTAssertEqual(c < 3, PIndexSet([false, true, false, false, true], setCount: 2))
        XCTAssertEqual(c > 2, PIndexSet([false, false, false, true, false], setCount: 1))
    }

    func testFilterWithNils() {
        let c = PTypedColumn([nil, 1, nil, 3])
        XCTAssertEqual(c.filter { $0 < 2}, PIndexSet([false, true, false, false], setCount: 1))
    }

    func testComparisons() {
        let c = PTypedColumn([nil, 1, 2, 1])
        XCTAssertEqual(c.compare(lhs: 0, rhs: 1), .gt)
        XCTAssertEqual(c.compare(lhs: 1, rhs: 2), .lt)
        XCTAssertEqual(c.compare(lhs: 1, rhs: 3), .eq)
        XCTAssertEqual(c.compare(lhs: 2, rhs: 0), .lt)
    }

    func testSorting() {
        var c = PTypedColumn([nil, 10, 20, 30])
        let indices = [2, 3, 0, 1]
        let expected = PTypedColumn([20, 30, nil, 10])
        c._sort(indices)
        XCTAssertEqual(c, expected)
    }

    func testEmptyInitString() {
        var c = PTypedColumn(empty: String.self)
        c.append("foo")
        c.append("bar")
        c.append("baz")

        let expected = PTypedColumn(["foo", "bar", "baz"])
        XCTAssertEqual(expected, c)
    }

    func testEmptyInitInts() {
        var c = PTypedColumn(empty: Int.self)
        c.append("1")
        c.append("-2")
        c.append(" 3 ")
        c.append("abcd")
        c.append(" 5")

        let expected = PTypedColumn([1, -2, 3, nil, 5])
        XCTAssertEqual(expected, c)
    }

    static var allTests = [
        ("testSum", testSum),
        ("testAvg", testAvg),
        ("testMap", testMap),
        ("testDescription", testDescription),
        ("testMinMax", testMinMax),
        ("testMinMaxOptionals", testMinMaxOptionals),
        ("testSubsetting", testSubsetting),
        ("testScalarEquality", testScalarEquality),
        ("testScalarInequality", testScalarInequality),
        ("testScalarComparisons", testScalarComparisons),
        ("testArbitraryFilter", testArbitraryFilter),
        ("testElementSubscript", testElementSubscript),
        ("testOptionalColumn", testOptionalColumn),
        ("testSubscriptGatherWithNils", testSubscriptGatherWithNils),
        ("testOptionalSubscript", testOptionalSubscript),
        ("testScalarComparasonsWithNils", testScalarComparasonsWithNils),
        ("testFilterWithNils", testFilterWithNils),
        ("testComparisons", testComparisons),
        ("testSorting", testSorting),
        ("testEmptyInitString", testEmptyInitString),
        ("testEmptyInitInts", testEmptyInitInts),
    ]
}
