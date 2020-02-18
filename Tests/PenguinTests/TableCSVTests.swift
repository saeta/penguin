import XCTest
@testable import Penguin

final class TableCSVTests: XCTestCase {
    func testSimpleParse() throws {
        let table = try PTable(csvContents: """
            a,b,c,d
            asdf,1,2,3.1
            fdsa,4,5,6.2
            """)

        let colA = PColumn(["asdf", "fdsa"])
        let colB = PColumn([1, 4])
        let colC = PColumn([2, 5])
        let colD = PColumn([3.1, 6.2])
        let expected = try! PTable([("a", colA), ("b", colB), ("c", colC), ("d", colD)])
        XCTAssertEqual(expected, table)
    }

    func testTsvParseWithTrailingNewline() throws {
        let table = try PTable(csvContents: """
        a\tb\tc
        Pi\t3.14159\t-100
        e\t2.71828\t200

        """)
        let colA = PColumn(["Pi", "e"])
        let colB = PColumn([3.14159, 2.71828])
        let colC = PColumn([-100, 200])
        let expected = try! PTable([("a", colA), ("b", colB), ("c", colC)])
        XCTAssertEqual(expected, table)
    }

    static var allTests = [
        ("testSimpleParse", testSimpleParse),
        ("testTsvParseWithTrailingNewline", testTsvParseWithTrailingNewline)
    ]
}
