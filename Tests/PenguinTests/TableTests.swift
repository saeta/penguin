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

    static var allTests = [
        ("testDifferentColumnCounts", testDifferentColumnCounts),
        ("testColumnRenaming", testColumnRenaming),
        ("testDescription", testDescription),
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
