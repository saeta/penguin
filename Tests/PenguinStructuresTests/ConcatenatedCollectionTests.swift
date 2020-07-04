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
    let s = Set(["1", "2", "3"])
    let c = s.concatenated(with: ["10", "11", "12"])
    c.checkCollectionSemantics(expectedValues: Array(s) + ["10", "11", "12"])
  }

  func testConcatenateRanges() {
    let c = (0..<3).concatenated(with: 3...6)
    c.checkRandomAccessCollectionSemantics(expectedValues: 0...6)
  }

  func testConcatenatingEmptyPrefix() {
    let c = (0..<0).concatenated(with: [1, 2, 3])
    c.checkRandomAccessCollectionSemantics(expectedValues: 1...3)
  }

  func testConcatenatingEmptySuffix() {
    let c = (1...3).concatenated(with: 1000..<1000)
    c.checkRandomAccessCollectionSemantics(expectedValues: [1, 2, 3])
  }

  static var allTests = [
    ("testConcatenateSetAndList", testConcatenateSetAndList),
    ("testConcatenateRanges", testConcatenateRanges),
    ("testConcatenatingEmptyPrefix", testConcatenatingEmptyPrefix),
    ("testConcatenatingEmptySuffix", testConcatenatingEmptySuffix),
  ]
}
