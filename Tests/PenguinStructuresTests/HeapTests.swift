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

final class HeapTests: XCTestCase {
  func testHeapOperations() {
    var a = [0, 1, 2, 3, 4, 5, 6]
    XCTAssert(a.isMinHeap)

    XCTAssertEqual(0, a.popMinHeap())
    XCTAssertEqual([1, 3, 2, 6, 4, 5], a)
    XCTAssert(a.isMinHeap)

    XCTAssertEqual(1, a.popMinHeap())
    XCTAssertEqual([2, 3, 5, 6, 4], a)
    XCTAssert(a.isMinHeap)

    for i in 2..<7 {
      XCTAssertEqual(i, a.popMinHeap())
      XCTAssert(a.isMinHeap)
    }
    XCTAssertNil(a.popMinHeap())
    XCTAssert(a.isMinHeap)
    a.insertMinHeap(42)
    XCTAssert(a.isMinHeap)
    XCTAssertEqual([42], a)

    a = [3, 2, 1, 5, 7, 8, 0, 17, 8]
    a.arrangeAsMinHeap()
    XCTAssert(a.isMinHeap)

    a.insertMinHeap(0)
    XCTAssert(a.isMinHeap)
    XCTAssertEqual([0, 0, 1, 5, 2, 8, 3, 17, 8, 7], a)
  }

  func testSimple() {
    var h = SimplePriorityQueue<Int>()

    let insertSequence = Array(0..<100).shuffled()
    for i in insertSequence {
      h.push(i, at: i)
    }
    for i in 0..<100 {
      XCTAssertEqual(i, h.pop()?.payload)
    }
    XCTAssertNil(h.pop())
  }

  func testUpdatableUniqueHeapSimple() {
    // var h = makeReprioritizableHeap()
    // XCTAssertEqual("x", h.popFront())
    // XCTAssertEqual("y", h.popFront())
    // XCTAssertEqual("z", h.popFront())
    // XCTAssertEqual(nil, h.popFront())

    // h = makeReprioritizableHeap()
    // h.update("x", withNewPriority: 20)
    // XCTAssertEqual("y", h.popFront())
    // XCTAssertEqual("z", h.popFront())
    // XCTAssertEqual("x", h.popFront())
    // XCTAssertEqual(nil, h.popFront())

    // h = makeReprioritizableHeap()
    // h.update("z", withNewPriority: 5)
    // XCTAssertEqual("z", h.popFront())
    // XCTAssertEqual("x", h.popFront())
    // XCTAssertEqual("y", h.popFront())
    // XCTAssertEqual(nil, h.popFront())
  }

  // func makeReprioritizableHeap() -> ReprioritizableHeap<String> {
  //   var h = ReprioritizableHeap<String>()
  //   h.add("x", with: 10)
  //   h.add("y", with: 11)
  //   h.add("z", with: 12)

  //   return h
  // }

  static var allTests = [
    ("testHeapOperations", testHeapOperations),
    ("testSimple", testSimple),
    ("testUpdatableUniqueHeapSimple", testUpdatableUniqueHeapSimple),
  ]
}
