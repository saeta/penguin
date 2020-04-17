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

final class DequeTests: XCTestCase {

  func testSimple() {
    var d = Deque<Int>()
    let count = 2048  // Enough elemets to ensure we make new blocks.

    // Add a bunch of elements to the back and pop from the front and ensure
    // they are appropriate.
    for i in 0..<count {
      XCTAssertEqual(i, d.count)
      d.pushBack(i)
      XCTAssertFalse(d.isEmpty)
    }
    XCTAssertEqual(count, d.count)

    for i in 0..<count {
      XCTAssertFalse(d.isEmpty)
      XCTAssertEqual(count - i, d.count)
      XCTAssertEqual(i, d.popFront())
    }
    XCTAssert(d.isEmpty)

    for i in 0..<count {
      XCTAssertEqual(i, d.count)
      d.pushFront(i)
    }
    for i in 0..<count {
      XCTAssertEqual(i, d.popBack())
    }
  }

  func testValueSemantics() {
    var d = Deque<Int>()
    let t0 = d

    for i in 0..<2048 {
      d.pushBack(i)
    }

    var t1 = d

    for i in 2048..<(2048 * 8) {
      d.pushBack(i)
    }

    XCTAssertEqual(2048 * 8, d.count)
    XCTAssertEqual(2048, t1.count)
    XCTAssertEqual(0, t0.count)

    for i in 0..<2048 {
      XCTAssertEqual(i, t1.popFront())
    }

    for i in 0..<(2048 * 8) {
      XCTAssertEqual(i, d.popFront())
    }
  }

  func testHierarchicalCollection() {
    var d = Deque<Int>()
    for i in 0..<2048 {
      d.pushBack(i)
    }
    XCTAssertEqual(Array(0..<2048), d.flatten())
  }

  static var allTests = [
    ("testSimple", testSimple),
    ("testValueSemantics", testValueSemantics),
    ("testHierarchicalCollection", testHierarchicalCollection),
  ]
}
