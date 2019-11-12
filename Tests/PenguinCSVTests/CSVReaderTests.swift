import XCTest
@testable import PenguinCSV

final class CSVReaderTests: XCTestCase {
    func testSimpleRow() throws {
        let contents = """
        a,b,1,2
        """
        let reader = try CSVReader(contents: contents)
        let expected = [
            ["a", "b", "1", "2"],
        ]
        XCTAssertEqual(reader.readAll(), expected)
    }

    func testSimpleMultipleRows() throws {
        let contents = """
        a,b,c,d
        1,2,3,4
        5,6,7,8
        """
        let reader = try CSVReader(contents: contents)
        let expected = [
            ["a", "b", "c", "d"],
            ["1", "2", "3", "4"],
            ["5", "6", "7", "8"],
        ]
        XCTAssertEqual(reader.readAll(), expected)
    }

    func testQuotedCell() throws {
        let contents = """
        a,b,c,d
        1,2,"three of c's",4
        """
        let reader = try CSVReader(contents: contents)
        let expected = [
            ["a", "b", "c", "d"],
            ["1", "2", "three of c's", "4"],
        ]
        XCTAssertEqual(reader.readAll(), expected)
    }

    func testQuotedCellAtEndOfLine() throws {
        let contents = """
        a,b,c
        1,2,"three of c's"
        4,5,6
        """
        let reader = try CSVReader(contents: contents)
        let expected = [
            ["a", "b", "c"],
            ["1", "2", "three of c's"],
            ["4", "5", "6"],
        ]
        XCTAssertEqual(reader.readAll(), expected)
    }

    func testEmptyAtEnd() throws {
        let contents = """
        a,b,c
        1,2,
        """
        let reader = try CSVReader(contents: contents)
        let expected = [
            ["a", "b", "c"],
            ["1", "2", ""],
        ]
        XCTAssertEqual(reader.readAll(), expected)
    }

    func testEmptyAtEndAfterQuote() throws {
        let contents = """
        a,b,c
        1,"2",
        """
        let reader = try CSVReader(contents: contents)
        let expected = [
            ["a", "b", "c"],
            ["1", "2", ""],
        ]
        XCTAssertEqual(reader.readAll(), expected)
    }

    func testUnevenLines() throws {
        let contents = """
        a,b,c,d
        1,2,
        5,6,7,8
        """
        let reader = try CSVReader(contents: contents)
        let expected = [
            ["a", "b", "c", "d"],
            ["1", "2", ""],
            ["5", "6", "7", "8"],
        ]
        XCTAssertEqual(reader.readAll(), expected)
    }

    func testEmbeddedNewline() throws {
        let contents = """
        a,b,c
        1,"two\nwith a newline",3
        """
        let reader = try CSVReader(contents: contents)
        let expected = [
            ["a", "b", "c"],
            ["1", "two\nwith a newline", "3"],
        ]
        XCTAssertEqual(reader.readAll(), expected)
    }

    func testEscaping() throws {
        let contents = """
        a,b,c
        1,"two, aka \\"super cool\\"",3
        """
        let reader = try CSVReader(contents: contents)
        let expected = [
            ["a", "b", "c"],
            ["1", "two, aka \"super cool\"", "3"],
        ]
        XCTAssertEqual(reader.readAll(), expected)
    }

    static var allTests = [
        ("testSimpleRow", testSimpleRow),
        ("testSimpleMultipleRows", testSimpleMultipleRows),
        ("testQuotedCell", testQuotedCell),
        ("testQuotedCellAtEndOfLine", testQuotedCellAtEndOfLine),
        ("testEmptyAtEnd", testEmptyAtEnd),
        ("testEmptyAtEndAfterQuote", testEmptyAtEndAfterQuote),
        ("testUnevenLines", testUnevenLines),
        ("testEmbeddedNewline", testEmbeddedNewline),
        ("testEscaping", testEscaping),
    ]
}
