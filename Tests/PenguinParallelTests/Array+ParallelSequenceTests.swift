import XCTest
import PenguinParallel

final class ArrayParallelSequenceTests: XCTestCase {

    func testPSum() {
        let arr = Array(0..<100000)
        XCTAssertEqual(arr.pSum(), arr.reduce(0, +))
    }

    func testMap() {
        let arr = Array(200..<10000)
        let parallel = arr.pMap { (($0-500)..<$0).reduce(0, +) }
        let sequential = arr.map { (($0-500)..<$0).reduce(0, +) }
        XCTAssertEqual(parallel, sequential)
    }

    static var allTests = [
        ("testPSum", testPSum),
        ("testMap", testMap),
    ]
}
