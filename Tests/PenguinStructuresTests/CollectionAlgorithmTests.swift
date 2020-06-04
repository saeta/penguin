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

final class CollectionAlgorithmTests: XCTestCase {

  func testHalfStablePartitionEmptyDelayIndices() {
    var data = Array(0..<10)
    data.halfStablePartition(delaying: [])
    XCTAssertEqual(Array(0..<10), data)
  }

  func testHalfStablePartitionConsecutiveIndices() {
    var data = Array(100..<110)
    data.halfStablePartition(delaying: [2, 3, 4])
    XCTAssertEqual([100, 101, 105, 106, 107, 108, 109, 104, 102, 103], data)
  }

  func testHalfStablePartitionEmptyData() {
    var data = [Int]()
    data.halfStablePartition(delaying: [0])
    XCTAssertEqual([], data)

    data.halfStablePartition(delaying: [])
    XCTAssertEqual([], data)
  }

  func testHalfStablePartitionByIndicesConsecutiveThroughEnd() {
    var data = Array(0..<10)
    let delayIndices = [2, 3, 7, 8, 9]
    data.halfStablePartition(delaying: delayIndices)
    XCTAssertEqual([0, 1, 4, 5, 6], Array(data[0..<(data.count - delayIndices.count)]))
    XCTAssertEqual(Set(delayIndices), Set(data[(data.count - delayIndices.count)...]))
  }

  static var allTests = [
    ("testHalfStablePartitionEmptyDelayIndices", testHalfStablePartitionEmptyDelayIndices),
    ("testHalfStablePartitionConsecutiveIndices", testHalfStablePartitionConsecutiveIndices),
    ("testHalfStablePartitionEmptyData", testHalfStablePartitionEmptyData),
    ("testHalfStablePartitionByIndicesConsecutiveThroughEnd", testHalfStablePartitionByIndicesConsecutiveThroughEnd),
  ]
}
