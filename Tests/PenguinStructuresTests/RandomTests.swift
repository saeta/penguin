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

import PenguinStructures
import XCTest

final class RandomTests: XCTestCase {
  func testRandomSelectionWithoutReplacementRandomAccessCollection() {
    XCTAssertEqual(Array(0..<10), (0..<10).randomSelectionWithoutReplacement(k: 10))
    XCTAssertEqual([], (0..<Int.max).randomSelectionWithoutReplacement(k: 0))
    XCTAssertEqual(2, (0..<42_000).randomSelectionWithoutReplacement(k: 2).count)
    XCTAssertEqual(Array(0..<100), (0..<100).randomSelectionWithoutReplacement(k: 1000))

    do {
      let k = 100
      let selection = (0..<42_000).randomSelectionWithoutReplacement(k: 100)
      XCTAssertEqual(k, Set(selection).count, "\(selection)")
    }

    do {
      let k = 5
      var selection = (0..<1100)[1000...].randomSelectionWithoutReplacement(k: k)
      selection.sort()
      XCTAssertEqual(k, selection.count)
      XCTAssert(selection[0] >= 1000, "\(selection)")
      XCTAssert(selection[0] <= 1100, "\(selection)")
      XCTAssertEqual(k, Set(selection).count)
    }
  }

  func testRandomSelectionWithoutReplacementCollection() {
    // We use set as our non-random access collection.
    XCTAssertEqual(Array(0..<10), Set(0..<10).randomSelectionWithoutReplacement(k: 10).sorted())
    XCTAssertEqual([], Set(0..<100_000).randomSelectionWithoutReplacement(k: 0))
    XCTAssertEqual(2, Set(0..<42_000).randomSelectionWithoutReplacement(k: 2).count)
    XCTAssertEqual(Array(0..<100), Set(0..<100).randomSelectionWithoutReplacement(k: 1000).sorted())

    do {
      let k = 100
      let selection = Set(0..<42_000).randomSelectionWithoutReplacement(k: k)
      XCTAssertEqual(k, Set(selection).count, "\(selection)")
    }
  }

  static var allTests = [
    ("testRandomSelectionWithoutReplacementRandomAccessCollection", testRandomSelectionWithoutReplacementRandomAccessCollection),
    ("testRandomSelectionWithoutReplacementCollection", testRandomSelectionWithoutReplacementCollection),
  ]
}
