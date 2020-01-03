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

    func testPSum() {
        let arr = Array(0..<100000)
        XCTAssertEqual(arr.psum(), arr.reduce(0, +))
    }

    func testMap() {
        let arr = Array(200..<10000)
        let parallel = arr.pmap { (($0-500)..<$0).reduce(0, +) }
        let sequential = arr.map { (($0-500)..<$0).reduce(0, +) }
        XCTAssertEqual(parallel, sequential)
    }

    static var allTests = [
        ("testParallelIteratorOnArray", testParallelIteratorOnArray),
        ("testPSum", testPSum),
        ("testMap", testMap),
    ]
}
