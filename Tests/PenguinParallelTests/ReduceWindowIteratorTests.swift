import XCTest
import PenguinParallel

final class ReduceWindowIteratorTests: XCTestCase {
    func testReduceWindowSimple() throws {
        var itr = PipelineIterator.range(to: 10).reduceWindow(windowSize: 3) {
            try $0.collect().sum()
        }
        XCTAssertEqual(3, try! itr.next())  // 0, 1, 2
        XCTAssertEqual(12, try! itr.next())  // 3, 4, 5
        XCTAssertEqual(21, try! itr.next())  // 6, 7, 8
        XCTAssertEqual(19, try! itr.next()) // 9, 10
        XCTAssertNil(try! itr.next())
    }

    static var allTests = [
        ("testReduceWindowSimple", testReduceWindowSimple),
    ]
}

fileprivate extension Array where Element == Int {
    func sum() -> Int {
        reduce(0, &+)
    }
}
