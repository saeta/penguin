import XCTest
import PenguinParallel

final class RandomIndiciesIteratorTests: XCTestCase {
    func testAllIndicesProducedOnce() throws {
        var seenIndices = Set<Int>()
        seenIndices.reserveCapacity(100)
        var itr = RandomIndicesIterator(count: 100, rng: SystemRandomNumberGenerator())
        while let i = itr.next() {
            XCTAssertFalse(seenIndices.contains(i), "Encountered \(i) unexpectedly; seen (\(seenIndices.count) seen so far): \(seenIndices).")
            seenIndices.insert(i)
        }
        XCTAssertEqual(100, seenIndices.count)
    }

    func testCollect() throws {
        let rng = SystemRandomNumberGenerator()
        let expected = Set(0..<100)
        for _ in 0..<10 {
            var itr = RandomIndicesIterator(count: 100, rng: rng)
            let output = try Set(itr.collect())
            XCTAssertEqual(expected, output)
        }
    }

    static var allTests = [
        ("testAllIndicesProducedOnce", testAllIndicesProducedOnce),
        ("testCollect", testCollect),
    ]
}
