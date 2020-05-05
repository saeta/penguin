// Copyright 2020 Penguin Authors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import PenguinPipeline
import XCTest

final class RandomIndiciesIteratorTests: XCTestCase {
  func testAllIndicesProducedOnce() throws {
    var seenIndices = Set<Int>()
    seenIndices.reserveCapacity(100)
    var itr = RandomIndicesIterator(count: 100, rng: SystemRandomNumberGenerator())
    while let i = itr.next() {
      XCTAssertFalse(
        seenIndices.contains(i),
        "Encountered \(i) unexpectedly; seen (\(seenIndices.count) seen so far): \(seenIndices).")
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
