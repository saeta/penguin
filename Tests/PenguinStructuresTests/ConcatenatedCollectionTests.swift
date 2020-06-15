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

final class ConcatenatedCollectionTests: XCTestCase {

  func testConcatenateSetAndList() {
    let c = Set(["1", "2", "3"]).concatenated(with: ["10", "11", "12"])
    XCTAssertFalse(c.isEmpty)
    XCTAssertEqual(6, c.count)
    XCTAssertEqual(Set(["1", "2", "3"]), Set(c.prefix(3)))
    XCTAssertEqual(["10", "11", "12"], Array(c.suffix(3)))
  }

  func testConcatenateRanges() {
    let c = (0..<3).concatenated(with: 3...6)
    XCTAssertEqual(Array(0...6), Array(c))    
  }

  func testConcatenateBidirectionalOperations() {
    let c = (0..<3).concatenated(with: [10, 11, 12])
    XCTAssertEqual(6, c.count)
    XCTAssertEqual([12, 11, 10, 2, 1, 0], Array(c.reversed()))
  }

  static var allTests = [
    ("testConcatenateSetAndList", testConcatenateSetAndList),
    ("testConcatenateRanges", testConcatenateRanges),
    ("testConcatenateBidirectionalOperations", testConcatenateBidirectionalOperations),
  ]
}
