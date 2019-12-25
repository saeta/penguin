import XCTest
import PenguinParallel

final class ZipPipelineIteratorTests: XCTestCase {

    func testZipAndMapTwoArrays() {
        let arr = [0, 1, 2, 3, 4]
        var tmp = PipelineIterator.zip(arr.makePipelineIterator(), arr.makePipelineIterator().map { $0 + 1 })
        var itr = tmp.map { $0.0 + $0.1 }
        XCTAssertEqual(1, try! itr.next())
        XCTAssertEqual(3, try! itr.next())
        XCTAssertEqual(5, try! itr.next())
        XCTAssertEqual(7, try! itr.next())
        XCTAssertEqual(9, try! itr.next())
        XCTAssertEqual(nil, try! itr.next())
    }

    static var allTests = [
        ("testZipAndMapTwoArrays", testZipAndMapTwoArrays),
    ]
}
