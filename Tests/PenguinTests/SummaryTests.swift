import XCTest
@testable import Penguin

final class SummaryTests: XCTestCase {

    func testIntSummary() throws {
        let summary = computeNumericSummary([1, 10, 100, -1], PIndexSet([false, false, false, true], setCount: 1))
        XCTAssertEqual(4, summary.rowCount)
        XCTAssertEqual(1, summary.missingCount)
        let details = try assertNumericDetails(summary)
        XCTAssertEqual(1, details.min)
        XCTAssertEqual(100, details.max)
        XCTAssertEqual(111, details.sum)
        XCTAssertEqual(37, details.mean)
        XCTAssertEqual(0, details.zeroCount)
        XCTAssertEqual(0, details.negativeCount)
        XCTAssertEqual(3, details.positiveCount)
        XCTAssertEqual(0, details.nanCount)
        XCTAssertEqual(0, details.infCount)
    }

    func testDoubleSummary() throws {
        let summary = computeNumericSummary([-1, 301, 150, -1, 0, 0], PIndexSet([false, false, false, true, false, true], setCount: 2))
        XCTAssertEqual(6, summary.rowCount)
        XCTAssertEqual(2, summary.missingCount)
        let details = try assertNumericDetails(summary)
        XCTAssertEqual(-1, details.min)
        XCTAssertEqual(301, details.max)
        XCTAssertEqual(450, details.sum)
        XCTAssertEqual(112.5, details.mean)
        XCTAssertEqual(1, details.zeroCount)
        XCTAssertEqual(1, details.negativeCount)
        XCTAssertEqual(2, details.positiveCount)
        XCTAssertEqual(0, details.nanCount)
        XCTAssertEqual(0, details.infCount)
    }

    // TODO: Handle NaN's and Infinities!

    static var allTests = [
        ("testIntSummary", testIntSummary),
        ("testDoubleSummary", testDoubleSummary),
    ]
}

fileprivate func assertNumericDetails(_ summary: PColumnSummary) throws -> PNumericDetails {
    switch summary.details {
    case let .numeric(details):
        return details
    default:
        XCTFail("No numeric details in \(summary).")
        throw TestFailure.bad
    }
}

enum TestFailure: Error {
    case bad
}
