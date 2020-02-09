import XCTest
@testable import PenguinParallel

final class ParallelUtilitiesTests: XCTestCase {
    func testComputeRecursiveDepth() {
        XCTAssertEqual(6, computeRecursiveDepth(procCount: 64))
        XCTAssertEqual(7, computeRecursiveDepth(procCount: 72))
        XCTAssertEqual(7, computeRecursiveDepth(procCount: 112))
        XCTAssertEqual(4, computeRecursiveDepth(procCount: 12))
    }

    static var allTests = [
        ("testComputeRecursiveDepth", testComputeRecursiveDepth),
    ]
}
