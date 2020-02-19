import XCTest
@testable import Penguin

final class TableTests: XCTestCase {
    func testDifferentColumnCounts() {
        let c1 = PColumn([1, 2, 3])
        let c2 = PColumn([1, 2, 3, 4])

        if let table = try? PTable([("c1", c1), ("c2", c2)]) {
            XCTFail("PTable initializer should have failed due to different column counts. Got: \(table)")
        }
    }

    func testColumnRenaming() {
        let c1 = PColumn([1, 2, 3])
        let c2 = PColumn([10, 20, 30])

        var table = try! PTable([("c1", c1), ("c2", c2)])
        XCTAssertEqual(table.columnNames, ["c1", "c2"])
        assertPColumnsEqual(table["c1"], c1, dtype: Int.self)
        assertPColumnsEqual(table["c2"], c2, dtype: Int.self)
        assertPColumnsEqual(table["cNotThere"], nil, dtype: Int.self)
        assertPColumnsEqual(table["c10"], nil, dtype: Int.self)

        // Rename columns
        table.columnNames = ["c1", "c10"]
        XCTAssertEqual(table.columnNames, ["c1", "c10"])
        assertPColumnsEqual(table["c1"], c1, dtype: Int.self)
        assertPColumnsEqual(table["c10"], c2, dtype: Int.self)
        assertPColumnsEqual(table["c2"], nil, dtype: Int.self)

        // Drop a column
        table.columnNames = ["c1"]
        XCTAssertEqual(table.columnNames, ["c1"])
        assertPColumnsEqual(table["c1"], c1, dtype: Int.self)
        assertPColumnsEqual(table["c10"], nil, dtype: Int.self)
        assertPColumnsEqual(table["c2"], nil, dtype: Int.self)

        // Rename last column
        table.columnNames = ["c"]
        XCTAssertEqual(table.columnNames, ["c"])
        assertPColumnsEqual(table["c"], c1, dtype: Int.self)
        assertPColumnsEqual(table["c1"], nil, dtype: Int.self)
        assertPColumnsEqual(table["c10"], nil, dtype: Int.self)
        assertPColumnsEqual(table["c2"], nil, dtype: Int.self)
    }

    func testDescription() {
        let c1 = PColumn([1, 2, 3])
        let c2 = PColumn([10, 20, 30])
        let table = try! PTable([("c1", c1), ("c2", c2)])
        XCTAssertEqual(table.description, """
        	c1	c2
        	Int	Int
        0	1	10
        1	2	20
        2	3	30
        
        """)
    }

    func testSubselectingColumns() {
        let c1 = PColumn([1, 2, 3])
        let c2 = PColumn([10, 20, 30])
        let c3 = PColumn([100, 200, 300])
        let table = try! PTable(["c1": c1, "c2": c2, "c3": c3])

        let subtable1 = table[["c1", "c3"]]
        XCTAssertEqual(subtable1.columnNames, ["c1", "c3"])
        assertPColumnsEqual(subtable1["c1"], c1, dtype: Int.self)
        assertPColumnsEqual(subtable1["c3"], c3, dtype: Int.self)
        assertPColumnsEqual(subtable1["c2"], nil, dtype: Int.self)
        assertPColumnsEqual(subtable1["c"], nil, dtype: Int.self)

        let subtable2 = table[["c1"]]
        XCTAssertEqual(subtable2.columnNames, ["c1"])
        assertPColumnsEqual(subtable2["c1"], c1, dtype: Int.self)
        assertPColumnsEqual(subtable2["c3"], nil, dtype: Int.self)
        assertPColumnsEqual(subtable2["c2"], nil, dtype: Int.self)
        assertPColumnsEqual(subtable2["c"], nil, dtype: Int.self)
    }

    func testEquality() {
        let c1 = PColumn([1, 2, 3])
        let c2 = PColumn([10.0, 20.0, 30.0])
        let c3 = PColumn(["100", "200", "300"])
        let table1 = try! PTable(["c1": c1, "c2": c2, "c3": c3])

        let c4 = PColumn([1, 2, 3])
        let c5 = PColumn([10.0, 20.0, 30.0])
        let c6 = PColumn(["100", "200", "300"])
        let table2 = try! PTable(["c1": c4, "c2": c5, "c3": c6])

        XCTAssertEqual(table1, table2)

        let table3 = try! PTable(["c4": c4, "c5": c5, "c6": c6])
        XCTAssertNotEqual(table2, table3)
    }

    func testCount() {
        let c1 = PColumn([1, 2, 3])
        let c2 = PColumn([10.0, 20.0, 30.0])
        let c3 = PColumn(["100", "200", "300"])
        let table = try! PTable(["c1": c1, "c2": c2, "c3": c3])

        XCTAssertEqual(table.count, 3)
    }

    func testIndexSubsetting() {
        let c1 = PColumn([1, 2, 3])
        let c2 = PColumn([10.0, 20.0, 30.0])
        let c3 = PColumn(["100", "200", "300"])
        let table = try! PTable(["c1": c1, "c2": c2, "c3": c3])

        let expected1 = PColumn([1, 3])
        let expected2 = PColumn([10.0, 30.0])
        let expected3 = PColumn(["100", "300"])
        let expected = try! PTable(["c1": expected1, "c2": expected2, "c3": expected3])

        let indexSet = PIndexSet(indices: [0, 2], count: 3)

        XCTAssertEqual(c1[indexSet], expected1)
        let cErased1 = c1 as PColumn
        XCTAssertEqual(cErased1[indexSet], expected1)
        XCTAssertEqual(table[indexSet], expected)
    }

    func testRenaming() {
        let c1 = PColumn([1, 2, 3])
        let c2 = PColumn([10.0, 20.0, 30.0])
        let c3 = PColumn(["100", "200", "300"])
        var table = try! PTable(["c1": c1, "c2": c2, "c3": c3])

        try! table.rename("c1", to: "c")
        XCTAssertEqual(table, try! PTable(["c": c1, "c2": c2, "c3": c3]))
    }

    func testDropping() {
        let c1 = PColumn([1, 2, 3])
        let c2 = PColumn([10.0, 20.0, 30.0])
        let c3 = PColumn(["100", "200", "300"])
        var table = try! PTable(["c1": c1, "c2": c2, "c3": c3])

        table.drop("c3", "c2", "notthere")
        XCTAssertEqual(table, try! PTable(["c1": c1]))

        table = try! PTable(["c1": c1, "c2": c2, "c3": c3])
        try! table.drop(columns: "c1", "c2")
        XCTAssertEqual(table, try! PTable(["c3": c3]))

        do {
            try table.drop(columns: "c1")
            XCTFail("Should have thrown an error above.")
        } catch let PError.unknownColumn(colName) {
            XCTAssertEqual(colName, "c1")
        } catch let err {
            XCTFail("Failed! \(err)")
        }
    }

    func testElementAccess() {
        let c1 = PColumn([1, 2, 3])
        let c2 = PColumn([10.0, 20.0, 30.0])
        let c3 = PColumn(["100", "200", "300"])
        var table = try! PTable(["c1": c1, "c2": c2, "c3": c3])

        XCTAssertEqual(table["c1", 1], 2)
        table["c2", 0] = 1.0
        XCTAssertEqual(table["c2", 0], 1.0)
    }

    func testTMap() {
        let c1 = PColumn([1, 2, 3])
        let c2 = PColumn([10.0, 20.0, 30.0])
        let c3 = PColumn(["100", "200", "300"])
        let table = try! PTable(["c1": c1, "c2": c2, "c3": c3])

        let expected = PColumn([11.0, 21.0, 31.0])
        let output = table.tmap("c2") { (c2: Double) in c2 + 1 }
        XCTAssertEqual(output, expected.asDouble())
    }

    func testDropNils() {
        let c1 = PColumn([1, nil, 3, 4, 5])
        let c2 = PColumn([1.0, 2.0, 3.0, 4.0, 5.0])
        let c3 = PColumn(["1", "2", nil, "4", "5"])
        let table = try! PTable(["c1": c1, "c2": c2, "c3": c3])

        let expected1 = PColumn([1, 4, 5])
        let expected2 = PColumn([1.0, 4.0, 5.0])
        let expected3 = PColumn(["1", "4", "5"])
        let expected = try! PTable(["c1": expected1, "c2": expected2, "c3": expected3])

        XCTAssertEqual(table.droppedNils(), expected)
    }

    func testSorting() {
        let c1 = PColumn([1, 2, 3, 4, 5])
        let c2 = PColumn([30.0, 10.0, 30.0, nil, nil])
        let c3 = PColumn(["200", "200", "100", nil, "0"])
        let table = try! PTable(["c1": c1, "c2": c2, "c3": c3])

        let expected1 = PColumn([2, 3, 1, 5, 4])
        let expected2 = PColumn([10.0, 30.0, 30.0, nil, nil])
        let expected3 = PColumn(["200", "100", "200", "0", nil])
        let expected = try! PTable(["c1": expected1, "c2": expected2, "c3": expected3])

        XCTAssertEqual(table.sorted(by: "c2", "c3"), expected)
    }

    func testSummarize() throws {
        let c1 = PColumn([1, 2, 3, 4, 5])
        let c2 = PColumn([30.0, 10.0, 30.0, nil, nil])
        let c3 = PColumn(["200", "200", "100", nil, "0"])
        let table = try! PTable(["c1": c1, "c2": c2, "c3": c3])

        let summaries = table.summarize()
        XCTAssertEqual(3, summaries.count)
        XCTAssertEqual(["c1", "c2", "c3"], summaries.map { $0.0 })
        XCTAssertTrue(summaries.allSatisfy { $0.1.rowCount == 5 }, "\(summaries)")
        XCTAssertEqual([0, 2, 1], summaries.map { $0.1.missingCount })
        let c1Details = try assertNumericDetails(summaries[0].1)
        XCTAssertEqual(3, c1Details.mean)
        let c2Details = try assertNumericDetails(summaries[1].1)
        XCTAssertEqual(23.333333333333332, c2Details.mean)
        let c3Details = try assertStringDetails(summaries[2].1)
        XCTAssertEqual("0", c3Details.min)
    }

    static var allTests = [
        ("testDifferentColumnCounts", testDifferentColumnCounts),
        ("testColumnRenaming", testColumnRenaming),
        ("testDescription", testDescription),
        ("testSubselectingColumns", testSubselectingColumns),
        ("testEquality", testEquality),
        ("testCount", testCount),
        ("testIndexSubsetting", testIndexSubsetting),
        ("testRenaming", testRenaming),
        ("testDropping", testDropping),
        ("testElementAccess", testElementAccess),
        ("testTMap", testTMap),
        ("testDropNils", testDropNils),
        ("testSorting", testSorting),
        ("testSummarize", testSummarize),
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
