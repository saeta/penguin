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
    a.reorderAsMinHeap()
    XCTAssert(a.isMinHeap)

    a.insertMinHeap(0)
    XCTAssert(a.isMinHeap)
    XCTAssertEqual([0, 0, 1, 5, 2, 8, 3, 17, 8, 7], a)
  }

  func testHeapOperationCallbacks() {
    var heap = Array((0..<10).reversed())
    XCTAssertFalse(heap.isMinHeap)
    var indexes = ArrayPriorityQueueIndexer<Int, Int>(count: heap.count)

    /// Helper function that verifies the index is exactly consistent with
    /// the heap `a`.
    func assertIndexConsistent() {
      var seenElements = Set<Int>()
      // First, go through everything in the heap, and verify it has the correct index.
      for index in heap.indices {
        let element = heap[index]
        seenElements.insert(element)
        guard let elementPosition = indexes[element] else {
          XCTFail("Heap element \(element) was not indexed. \(indexes), \(heap).")
          return
        }
        XCTAssertEqual(elementPosition, index)
      }
      // Go through all elements not in the heap and ensure their index value is nil.
      for i in 0..<10 {
        if !seenElements.contains(i) {
          XCTAssertFalse(heap.contains(i), "\(i); \(indexes) \(heap)")
          XCTAssertNil(indexes[i], "\(i); \(indexes) \(heap)")
        }
      }
    }

    heap.reorderAsMinHeap { indexes[$0] = $1 }
    XCTAssert(indexes.table.allSatisfy { $0 != nil }, "\(indexes)")
    assertIndexConsistent()

    for i in 0..<4 {
      let popped = heap.popMinHeap { indexes[$0] = $1 }
      XCTAssertEqual(popped, i)
      assertIndexConsistent()
    }

    heap.insertMinHeap(2) { indexes[$0] = $1 }
    assertIndexConsistent()
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
    var h = makeReprioritizableHeap()
    XCTAssertEqual("x", h.pop()!.payload)
    XCTAssertEqual("y", h.pop()!.payload)
    XCTAssertEqual("z", h.pop()!.payload)
    XCTAssertEqual(nil, h.pop())

    h = makeReprioritizableHeap()
    h.update("x", withNewPriority: 20)
    XCTAssertEqual("y", h.pop()!.payload)
    XCTAssertEqual("z", h.pop()!.payload)
    XCTAssertEqual("x", h.pop()!.payload)
    XCTAssertEqual(nil, h.pop())

    h = makeReprioritizableHeap()
    h.update("z", withNewPriority: 5)
    XCTAssertEqual("z", h.pop()!.payload)
    XCTAssertEqual("x", h.pop()!.payload)
    XCTAssertEqual("y", h.pop()!.payload)
    XCTAssertEqual(nil, h.pop())
  }

  func makeReprioritizableHeap() -> ReprioritizablePriorityQueue<String, Int> {
    var h = ReprioritizablePriorityQueue<String, Int>()
    h.push("x", at: 10)
    h.push("y", at: 11)
    h.push("z", at: 12)

    return h
  }

  static var allTests = [
    ("testHeapOperations", testHeapOperations),
    ("testSimple", testSimple),
    ("testHeapOperationCallbacks", testHeapOperationCallbacks),
    ("testUpdatableUniqueHeapSimple", testUpdatableUniqueHeapSimple),
  ]
}
