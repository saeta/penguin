import XCTest
import PenguinParallel

final class ArrayParallelSequenceTests: XCTestCase {

    func testParallelIteratorOnArray() {
        let arr = [0, 1, 2, 3, 4]
        var itr = arr.makeParItr()
        XCTAssertEqual(0, try! itr.next())
        XCTAssertEqual(1, try! itr.next())
        XCTAssertEqual(2, try! itr.next())
        XCTAssertEqual(3, try! itr.next())
        XCTAssertEqual(4, try! itr.next())
    }

    static var allTests = [
        ("testParallelIteratorOnArray", testParallelIteratorOnArray),
    ]
}
