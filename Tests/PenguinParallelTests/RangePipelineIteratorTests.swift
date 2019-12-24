import XCTest
import PenguinParallel

final class RangePipelineIteratorTests: XCTestCase {

    func testRangePipelineIterator() {
        var itr = RangePipelineIterator(start: 1, end: 6, step: 2)
        XCTAssert(itr.isNextReady)
        XCTAssertEqual(1, try! itr.next())
        XCTAssertEqual(3, try! itr.next())
        XCTAssertEqual(5, try! itr.next())
        XCTAssertEqual(nil, try! itr.next())
    }

    func testRangeInit() {
        var itr = PipelineIterator.range(1..<4)
        XCTAssert(itr.isNextReady)
        XCTAssertEqual(1, try! itr.next())
        XCTAssertEqual(2, try! itr.next())
        XCTAssertEqual(3, try! itr.next())
        XCTAssertEqual(nil, try! itr.next())
    }

    func testClosedRangeInit() {
        var itr = PipelineIterator.range(1...4)
        XCTAssert(itr.isNextReady)
        XCTAssertEqual(1, try! itr.next())
        XCTAssertEqual(2, try! itr.next())
        XCTAssertEqual(3, try! itr.next())
        XCTAssertEqual(4, try! itr.next())
        XCTAssertEqual(nil, try! itr.next())
    }

    static var allTests = [
        ("testRangePipelineIterator", testRangePipelineIterator),
        ("testRangeInit", testRangeInit),
        ("testClosedRangeInit", testClosedRangeInit),
    ]
}
