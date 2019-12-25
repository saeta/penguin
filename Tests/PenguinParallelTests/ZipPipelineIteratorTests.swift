import XCTest
import PenguinParallel

final class ZipPipelineIteratorTests: XCTestCase {

    func testZipAndMapTwoArrays() {
        let arr = [0, 1, 2, 3, 4]
        let tmp = PipelineIterator.zip(arr.makePipelineIterator(), arr.makePipelineIterator().map { $0 + 1 })
        var itr = tmp.map { $0.0 + $0.1 }
        XCTAssertEqual(1, try! itr.next())
        XCTAssertEqual(3, try! itr.next())
        XCTAssertEqual(5, try! itr.next())
        XCTAssertEqual(7, try! itr.next())
        XCTAssertEqual(9, try! itr.next())
        XCTAssertEqual(nil, try! itr.next())
    }

    func testZipEndEarly() {
        var itr = PipelineIterator.zip([0, 1, 2].makePipelineIterator(), [0, 1].makePipelineIterator())
        XCTAssert(try! itr.next() != nil)
        XCTAssert(try! itr.next() != nil)
        XCTAssert(try! itr.next() == nil)
    }

    static var allTests = [
        ("testZipAndMapTwoArrays", testZipAndMapTwoArrays),
        ("testZipEndEarly", testZipEndEarly),
    ]
}
