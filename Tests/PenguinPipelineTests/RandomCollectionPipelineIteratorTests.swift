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
    ("testStringCollection", testStringCollection)
  ]
}
