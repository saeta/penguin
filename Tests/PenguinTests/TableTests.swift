import XCTest
@testable import Penguin

final class TableTests: XCTestCase {
    func testDifferentColumnCounts() {
        let c1 = PTypedColumn([1, 2, 3])
        let c2 = PTypedColumn([1, 2, 3, 4])

        if let table = try? PTable([("c1", c1), ("c2", c2)]) {
            XCTFail("PTable initializer should have failed due to different column counts. Got: \(table)")
        }
    }

    func testColumnRenaming() {
        let c1 = PTypedColumn([1, 2, 3])
        let c2 = PTypedColumn([10, 20, 30])

        var table = try! PTable([("c1", c1), ("c2", c2)])
        XCTAssertEqual(table.columns, ["c1", "c2"])
        assertPColumnsEqual(table["c1"], c1, dtype: Int.self)
        assertPColumnsEqual(table["c2"], c2, dtype: Int.self)
        assertPColumnsEqual(table["cNotThere"], nil, dtype: Int.self)
        assertPColumnsEqual(table["c10"], nil, dtype: Int.self)

        // Rename columns
        table.columns = ["c1", "c10"]
        XCTAssertEqual(table.columns, ["c1", "c10"])
        assertPColumnsEqual(table["c1"], c1, dtype: Int.self)
        assertPColumnsEqual(table["c10"], c2, dtype: Int.self)
        assertPColumnsEqual(table["c2"], nil, dtype: Int.self)

        // Drop a column
        table.columns = ["c1"]
        XCTAssertEqual(table.columns, ["c1"])
        assertPColumnsEqual(table["c1"], c1, dtype: Int.self)
        assertPColumnsEqual(table["c10"], nil, dtype: Int.self)
        assertPColumnsEqual(table["c2"], nil, dtype: Int.self)

        // Rename last column
        table.columns = ["c"]
        XCTAssertEqual(table.columns, ["c"])
        assertPColumnsEqual(table["c"], c1, dtype: Int.self)
        assertPColumnsEqual(table["c1"], nil, dtype: Int.self)
        assertPColumnsEqual(table["c10"], nil, dtype: Int.self)
        assertPColumnsEqual(table["c2"], nil, dtype: Int.self)
    }

    func testDescription() {
        let c1 = PTypedColumn([1, 2, 3])
        let c2 = PTypedColumn([10, 20, 30])
        let table = try! PTable([("c1", c1), ("c2", c2)])
        XCTAssertEqual(table.description, """
        	c1	c2
        0	1	10
        1	2	20
        2	3	30
        
        """)
    }

    func testSubselectingColumns() {
        let c1 = PTypedColumn([1, 2, 3])
        let c2 = PTypedColumn([10, 20, 30])
        let c3 = PTypedColumn([100, 200, 300])
        let table = try! PTable(["c1": c1, "c2": c2, "c3": c3])

        let subtable1 = table[["c1", "c3"]]
        XCTAssertEqual(subtable1.columns, ["c1", "c3"])
        assertPColumnsEqual(subtable1["c1"], c1, dtype: Int.self)
        assertPColumnsEqual(subtable1["c3"], c3, dtype: Int.self)
        assertPColumnsEqual(subtable1["c2"], nil, dtype: Int.self)
        assertPColumnsEqual(subtable1["c"], nil, dtype: Int.self)

        let subtable2 = table[["c1"]]
        XCTAssertEqual(subtable2.columns, ["c1"])
        assertPColumnsEqual(subtable2["c1"], c1, dtype: Int.self)
        assertPColumnsEqual(subtable2["c3"], nil, dtype: Int.self)
        assertPColumnsEqual(subtable2["c2"], nil, dtype: Int.self)
        assertPColumnsEqual(subtable2["c"], nil, dtype: Int.self)
    }

    func testEquality() {
        let c1 = PTypedColumn([1, 2, 3])
        let c2 = PTypedColumn([10.0, 20.0, 30.0])
        let c3 = PTypedColumn(["100", "200", "300"])
        let table1 = try! PTable(["c1": c1, "c2": c2, "c3": c3])

        let c4 = PTypedColumn([1, 2, 3])
        let c5 = PTypedColumn([10.0, 20.0, 30.0])
        let c6 = PTypedColumn(["100", "200", "300"])
        let table2 = try! PTable(["c1": c4, "c2": c5, "c3": c6])

        XCTAssertEqual(table1, table2)

        let table3 = try! PTable(["c4": c4, "c5": c5, "c6": c6])
        XCTAssertNotEqual(table2, table3)
    }

    func testCount() {
        let c1 = PTypedColumn([1, 2, 3])
        let c2 = PTypedColumn([10.0, 20.0, 30.0])
        let c3 = PTypedColumn(["100", "200", "300"])
        let table = try! PTable(["c1": c1, "c2": c2, "c3": c3])

        XCTAssertEqual(table.count, 3)
    }

    func testIndexSubsetting() {
        let c1 = PTypedColumn([1, 2, 3])
        let c2 = PTypedColumn([10.0, 20.0, 30.0])
        let c3 = PTypedColumn(["100", "200", "300"])
        let table = try! PTable(["c1": c1, "c2": c2, "c3": c3])

        let expected1 = PTypedColumn([1, 3])
        let expected2 = PTypedColumn([10.0, 30.0])
        let expected3 = PTypedColumn(["100", "300"])
        let expected = try! PTable(["c1": expected1, "c2": expected2, "c3": expected3])

        let indexSet = PIndexSet(indices: [0, 2], count: 3)

        XCTAssertEqual(c1[indexSet], expected1)
        let cErased1 = c1 as PColumn
        XCTAssertEqual(cErased1[indexSet] as! PTypedColumn<Int>, expected1)
        XCTAssertEqual(table[indexSet], expected)
    }

    static var allTests = [
        ("testDifferentColumnCounts", testDifferentColumnCounts),
        ("testColumnRenaming", testColumnRenaming),
        ("testDescription", testDescription),
        ("testSubselectingColumns", testSubselectingColumns),
        ("testEquality", testEquality),
        ("testCount", testCount),
        ("testIndexSubsetting", testIndexSubsetting),
    ]
}

fileprivate func assertPColumnsEqual<T: ElementRequirements>(
    _ lhs: PColumn?, _ rhs: PColumn?, dtype: T.Type, file: StaticString = #file, line: UInt = #line) {
    if lhs == nil && rhs == nil { return }

    guard let lhsT: PTypedColumn<T> = try? lhs?.asDType() else {
        XCTFail("lhs could not be interpreted as dtype \(dtype): \(String(describing: lhs))",
                file: file, line: line)
        return
    }
    guard let rhsT: PTypedColumn<T> = try? rhs?.asDType() else {
        XCTFail("rhs could not be interpreted as dtype \(dtype): \(String(describing: rhs))",
                file: file, line: line)
        return
    }
    XCTAssertEqual(lhsT, rhsT, file: file, line: line)
}
