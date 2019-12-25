import XCTest
import PenguinParallel

final class RangePipelineIteratorTests: XCTestCase {

    func testRangePipelineIterator() {
        var itr = RangePipelineIterator(start: 1, end: 6, step: 2)
        XCTAssertEqual(1, try! itr.next())
        XCTAssertEqual(3, try! itr.next())
        XCTAssertEqual(5, try! itr.next())
        XCTAssertEqual(nil, try! itr.next())
    }

    func testRangeInit() {
        var itr = PipelineIterator.range(1..<4)
        XCTAssertEqual(1, try! itr.next())
        XCTAssertEqual(2, try! itr.next())
        XCTAssertEqual(3, try! itr.next())
        XCTAssertEqual(nil, try! itr.next())
    }

    func testClosedRangeInit() {
        var itr = PipelineIterator.range(1...4)
        XCTAssertEqual(1, try! itr.next())
        XCTAssertEqual(2, try! itr.next())
        XCTAssertEqual(3, try! itr.next())
        XCTAssertEqual(4, try! itr.next())
        XCTAssertEqual(nil, try! itr.next())
    }

    func testEnumerated() {
        var itr = ["zero", "one", "two"].makePipelineIterator().enumerated()
        var tmp = try! itr.next()
        XCTAssertEqual(0, tmp?.0)
        XCTAssertEqual("zero", tmp?.1)
        tmp = try! itr.next()
        XCTAssertEqual(1, tmp?.0)
        XCTAssertEqual("one", tmp?.1)
        tmp = try! itr.next()
        XCTAssertEqual(2, tmp?.0)
        XCTAssertEqual("two", tmp?.1)
        XCTAssert(try! itr.next() == nil)
    }

    static var allTests = [
        ("testRangePipelineIterator", testRangePipelineIterator),
        ("testRangeInit", testRangeInit),
        ("testClosedRangeInit", testClosedRangeInit),
        ("testEnumerated", testEnumerated),
    ]
}
