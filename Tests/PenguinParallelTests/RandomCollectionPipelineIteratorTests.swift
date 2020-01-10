import XCTest
import PenguinParallel

final class RandomCollectionPipelineIteratorTests: XCTestCase {
    func testStringCollection() throws {
        let rng = SystemRandomNumberGenerator()
        let elements = ["one", "two", "three", "four", "five", "six"]
        var seen = Set<String>()
        var itr = RandomCollectionPipelineSequence(elements, rng).makeIterator()
        while let elem = itr.next() {
            XCTAssertFalse(seen.contains(elem), "Encountered \(elem) unexpected; seen: \(seen).")
            seen.insert(elem)
        }
        let expected = Set(elements)
        XCTAssertEqual(expected, seen)
    }

    static var allTests = [
        ("testStringCollection", testStringCollection),
    ]
}
