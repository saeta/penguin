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
        let metadata = try assertMetadataNotNil(reader)
        XCTAssert(metadata.hasHeaderRow)
        XCTAssertEqual(",", metadata.separator)
        XCTAssertEqual(4, metadata.columns.count)
        XCTAssertEqual("a", metadata.columns[0].name)
        XCTAssertEqual(.int, metadata.columns[0].type)
        XCTAssertEqual("b", metadata.columns[1].name)
        XCTAssertEqual(.int, metadata.columns[1].type)
        XCTAssertEqual("c", metadata.columns[2].name)
        XCTAssertEqual(.int, metadata.columns[2].type)
        XCTAssertEqual("d", metadata.columns[3].name)
        XCTAssertEqual(.int, metadata.columns[3].type)
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
        let metadata = try assertMetadataNotNil(reader)
        XCTAssert(metadata.hasHeaderRow)
        XCTAssertEqual(",", metadata.separator)
        XCTAssertEqual(4, metadata.columns.count)
        XCTAssertEqual("a", metadata.columns[0].name)
        XCTAssertEqual(.int, metadata.columns[0].type)
        XCTAssertEqual("b", metadata.columns[1].name)
        XCTAssertEqual(.int, metadata.columns[1].type)
        XCTAssertEqual("c", metadata.columns[2].name)
        XCTAssertEqual(.string, metadata.columns[2].type)
        XCTAssertEqual("d", metadata.columns[3].name)
        XCTAssertEqual(.int, metadata.columns[3].type)
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
        let metadata = try assertMetadataNotNil(reader)
        XCTAssert(metadata.hasHeaderRow)
        XCTAssertEqual(",", metadata.separator)
        XCTAssertEqual(3, metadata.columns.count)
        XCTAssertEqual("a", metadata.columns[0].name)
        XCTAssertEqual(.int, metadata.columns[0].type)
        XCTAssertEqual("b", metadata.columns[1].name)
        XCTAssertEqual(.int, metadata.columns[1].type)
        XCTAssertEqual("c", metadata.columns[2].name)
        XCTAssertEqual(.string, metadata.columns[2].type)

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
        let metadata = try assertMetadataNotNil(reader)
        XCTAssert(metadata.hasHeaderRow)
        XCTAssertEqual(",", metadata.separator)
        XCTAssertEqual(3, metadata.columns.count)
        XCTAssertEqual("a", metadata.columns[0].name)
        XCTAssertEqual(.int, metadata.columns[0].type)
        XCTAssertEqual("b", metadata.columns[1].name)
        XCTAssertEqual(.int, metadata.columns[1].type)
        XCTAssertEqual("c", metadata.columns[2].name)
        XCTAssertEqual(.int, metadata.columns[2].type)

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
        let metadata = try assertMetadataNotNil(reader)
        XCTAssert(metadata.hasHeaderRow)
        XCTAssertEqual(",", metadata.separator)
        XCTAssertEqual(3, metadata.columns.count)
        XCTAssertEqual("a", metadata.columns[0].name)
        XCTAssertEqual(.int, metadata.columns[0].type)
        XCTAssertEqual("b", metadata.columns[1].name)
        // XCTAssertEqual(.string, metadata.columns[1].type)  // TODO: fix me?
        XCTAssertEqual("c", metadata.columns[2].name)
        XCTAssertEqual(.int, metadata.columns[2].type)

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
        let metadata = try assertMetadataNotNil(reader)
        XCTAssert(metadata.hasHeaderRow)
        XCTAssertEqual(",", metadata.separator)
        XCTAssertEqual(4, metadata.columns.count)
        XCTAssertEqual("a", metadata.columns[0].name)
        XCTAssertEqual(.int, metadata.columns[0].type)
        XCTAssertEqual("b", metadata.columns[1].name)
        XCTAssertEqual(.int, metadata.columns[1].type)
        XCTAssertEqual("c", metadata.columns[2].name)
        XCTAssertEqual(.int, metadata.columns[2].type)
        XCTAssertEqual("d", metadata.columns[3].name)
        XCTAssertEqual(.int, metadata.columns[3].type)

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

fileprivate enum TestError: Error {
    case missingMetadata
}

fileprivate func assertMetadataNotNil(_ reader: CSVReader, file: StaticString = #file, line: UInt = #line) throws -> CSVGuess {
    XCTAssertNotNil(reader.metadata, file: file, line: line)
    guard let metadata = reader.metadata else { throw TestError.missingMetadata }
    return metadata
}
