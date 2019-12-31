import XCTest
import PenguinParallel

final class TakePipelineIteratorTests: XCTestCase {
    func testTake() throws {
        var itr = PipelineIterator.range(to: 10).take(3)
        XCTAssertEqual(0, try! itr.next())
        XCTAssertEqual(1, try! itr.next())
        XCTAssertEqual(2, try! itr.next())
        XCTAssertNil(try! itr.next())
    }

    func testDrop() throws {
        var itr = PipelineIterator.range(to: 5).drop(2)
        XCTAssertEqual(2, try! itr.next())
        XCTAssertEqual(3, try! itr.next())
        XCTAssertEqual(4, try! itr.next())
        XCTAssertEqual(5, try! itr.next())
        XCTAssertNil(try! itr.next())
    }

    static var allTests = [
        ("testTake", testTake),
        ("testDrop", testDrop),
    ]
}
