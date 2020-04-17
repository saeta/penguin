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
  func testSimple() {
    var h = SimpleHeap<Int>()

    let insertSequence = Array(0..<100).shuffled()
    for i in insertSequence {
      h.add(i, with: i)
    }
    for i in 0..<100 {
      XCTAssertEqual(i, h.popFront())
    }
    XCTAssertEqual(nil, h.popFront())
  }

  func testUpdatableUniqueHeapSimple() {
    var h = makeReprioritizableHeap()
    XCTAssertEqual("x", h.popFront())
    XCTAssertEqual("y", h.popFront())
    XCTAssertEqual("z", h.popFront())
    XCTAssertEqual(nil, h.popFront())

    h = makeReprioritizableHeap()
    h.update("x", withNewPriority: 20)
    XCTAssertEqual("y", h.popFront())
    XCTAssertEqual("z", h.popFront())
    XCTAssertEqual("x", h.popFront())
    XCTAssertEqual(nil, h.popFront())

    h = makeReprioritizableHeap()
    h.update("z", withNewPriority: 5)
    XCTAssertEqual("z", h.popFront())
    XCTAssertEqual("x", h.popFront())
    XCTAssertEqual("y", h.popFront())
    XCTAssertEqual(nil, h.popFront())
  }

  func makeReprioritizableHeap() -> ReprioritizableHeap<String> {
    var h = ReprioritizableHeap<String>()
    h.add("x", with: 10)
    h.add("y", with: 11)
    h.add("z", with: 12)

    return h
  }

  static var allTests = [
    ("testSimple", testSimple),
    ("testUpdatableUniqueHeapSimple", testUpdatableUniqueHeapSimple),
  ]
}
