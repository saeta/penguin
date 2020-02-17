import XCTest
@testable import Penguin

final class StringParsibleTests: XCTestCase {
    func testInt() {
        assertParses(expected: 3, source: "  3")
        assertParses(expected: 3, source: "  3  ")
        assertParses(expected: -100, source: "  -100 ")
        assertParses(expected: 0, source: "  0 ")
        assertParseFailure(a: Int.self, from: "NaN")
    }

    func testFloat() {
        assertParses(expected: Float(3.14159), source: " 3.14159 ")
        assertParses(expected: Float(-6.28318), source: " -6.28318")
        assertParses(expected: -Float.infinity, source: " -Inf ")
        XCTAssert(Float(parsing: " NaN ")!.isNaN)  // NaN's don't compare equal
        XCTAssert(Float(parsing: " nan ")!.isNaN)  // NaN's don't compare equal
        assertParseFailure(a: Float.self, from: " asdf")
    }

    func testDouble() {
        assertParses(expected: 3.14159, source: " 3.14159 ")
        assertParses(expected: -6.28318, source: " -6.28318")
        assertParses(expected: -Double.infinity, source: " -Inf ")
        XCTAssert(Double(parsing: " NaN ")!.isNaN)  // NaN's don't compare equal
        XCTAssert(Double(parsing: " nan ")!.isNaN)  // NaN's don't compare equal
        assertParseFailure(a: Double.self, from: " asdf")
    }

    func testBool() {
        assertParses(expected: true, source: "t")
        assertParses(expected: true, source: " t ")
        assertParses(expected: true, source: " T ")
        assertParses(expected: true, source: " TrUe ")
        assertParses(expected: true, source: " 1 ")
        assertParses(expected: false, source: "f")
        assertParses(expected: false, source: " F ")
        assertParses(expected: false, source: " F ")
        assertParses(expected: false, source: " FaLsE ")
        assertParses(expected: false, source: " 0 ")
        assertParseFailure(a: Bool.self, from: "3")
        assertParseFailure(a: Bool.self, from: "asdf")
        assertParseFailure(a: Bool.self, from: " NaN ")
    }

    static var allTests = [
        ("testInt", testInt),
        ("testFloat", testFloat),
        ("testDouble", testDouble),
        ("testBool", testBool),
    ]
}

fileprivate func assertParses<T: PStringParsible & Equatable>(expected: T, source: String, file: StaticString = #file, line: UInt = #line) {
    let result = T(parsing: source)
    XCTAssertEqual(expected, result, file: file, line: line)
}

fileprivate func assertParseFailure<T: PStringParsible>(
    a type: T.Type,
    from source: String,
    reason: String? = nil,
    file: StaticString = #file,
    line: UInt = #line
) {
    do {
        let unexpected = try T(parseOrThrow: source)
        XCTFail("\"\(source)\" parsed as \(type) unexpectedly as \(unexpected).", file: file, line: line)
    } catch {
        let msg = String(describing: error)
        if let reason = reason {
            XCTAssert(
                msg.contains(reason),
                "Error message \"\(msg)\" did not contain expected string \"\(reason)\".",
                file: file,
                line: line)
        }
    }
}
