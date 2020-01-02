import XCTest
import PenguinParallel

final class InterleavePipelineIteratorTests: XCTestCase {
    func testInterleave() throws {
        var itr = PipelineIterator.range(to: 3).interleave(cycleCount: 2) { PipelineIterator.range(from: (10 * $0), to: (10 * $0) + $0) }
        XCTAssertEqual(0, try! itr.next())
        XCTAssertEqual(10, try! itr.next())
        XCTAssertEqual(11, try! itr.next())
        XCTAssertEqual(20, try! itr.next())
        XCTAssertEqual(21, try! itr.next())
        XCTAssertEqual(30, try! itr.next())
        XCTAssertEqual(22, try! itr.next())
        XCTAssertEqual(31, try! itr.next())
        XCTAssertEqual(32, try! itr.next())
        XCTAssertEqual(33, try! itr.next())
        XCTAssertNil(try! itr.next())
    }

    static var allTests = [
        ("testInterleave", testInterleave),
    ]
}
