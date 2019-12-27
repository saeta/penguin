import XCTest
import PenguinParallel

final class TransformPipelineIteratorTests: XCTestCase {

    func testPipelineMapInts() {
        let arr = [0, 1, 2, 3, 4]
        var itr = arr.makePipelineIterator().map { $0 + 1 }
        XCTAssertEqual(1, try! itr.next())
        XCTAssertEqual(2, try! itr.next())
        XCTAssertEqual(3, try! itr.next())
        XCTAssertEqual(4, try! itr.next())
        XCTAssertEqual(5, try! itr.next())
        XCTAssertEqual(nil, try! itr.next())
    }

    func testFilterOdds() {
        let arr = [0, 1, 2, 3, 4]
        var itr = arr.makePipelineIterator().filter { $0 % 2 == 0 }
        XCTAssertEqual(0, try! itr.next())
        XCTAssertEqual(2, try! itr.next())
        XCTAssertEqual(4, try! itr.next())
        XCTAssertEqual(nil, try! itr.next())
    }

    func testCompactMap() {
        let arr = [0, 1, 2, 3, 4]
        var itr = arr.makePipelineIterator().compactMap { i -> Int? in
            if i % 2 == 0 {
                return i * 2
            } else { return nil }
        }
        XCTAssertEqual(0, try! itr.next())
        XCTAssertEqual(4, try! itr.next())
        XCTAssertEqual(8, try! itr.next())
        XCTAssertEqual(nil, try! itr.next())
    }

    // TODO: test the case where the upstream is slow, and consuming is fast.
    // TODO: test the case where one map function is extremely slow, and others are fast (ensure minimal blocking).
    // TODO: test transform function throwing things.
    // TODO: test ... 

    static var allTests = [
        ("testPipelineMapInts", testPipelineMapInts),
        ("testFilterOdds", testFilterOdds),
        ("testCompactMap", testCompactMap),
    ]
}
