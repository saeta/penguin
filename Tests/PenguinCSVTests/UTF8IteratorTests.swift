import XCTest
@testable import PenguinCSV

final class UTF8IteratorTests: XCTestCase {
    func testAscii() {
        let data = "hello world!".utf8CString.withUnsafeBytes { Data($0) }
        var itr = UTF8Parser(underlying: data.makeIterator())
        XCTAssertEqual(itr.next(), "h")
        XCTAssertEqual(itr.next(), "e")
        XCTAssertEqual(itr.next(), "l")
        XCTAssertEqual(itr.next(), "l")
        XCTAssertEqual(itr.next(), "o")
        XCTAssertEqual(itr.next(), " ")
        XCTAssertEqual(itr.next(), "w")
        XCTAssertEqual(itr.next(), "o")
        XCTAssertEqual(itr.next(), "r")
        XCTAssertEqual(itr.next(), "l")
        XCTAssertEqual(itr.next(), "d")
        XCTAssertEqual(itr.next(), "!")
    }

    func testNonAscii() {
        let data = "être".utf8CString.withUnsafeBytes { Data($0) }
        var itr = UTF8Parser(underlying: data.makeIterator())
        XCTAssertEqual(itr.next(), "ê")
        XCTAssertEqual(itr.next(), "t")
        XCTAssertEqual(itr.next(), "r")
        XCTAssertEqual(itr.next(), "e")
    }

    static var allTests = [
        ("testAscii", testAscii),
        ("testNonAscii", testNonAscii),
    ]
}
