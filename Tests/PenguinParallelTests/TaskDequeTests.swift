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

@testable import PenguinParallel
import XCTest

final class TaskDequeTests: XCTestCase {
  func testSimplePushAndPop() {
    let deque = TaskDeque<Int, PosixConcurrencyPlatform>.make()

    XCTAssert(deque.isEmpty)
    XCTAssertNil(deque.pushFront(1))
    XCTAssertFalse(deque.isEmpty)
    XCTAssertEqual(1, deque.popFront(), "deque: \(deque)")

    XCTAssertNil(deque.pushBack(2))
    XCTAssertFalse(deque.isEmpty)
    XCTAssertEqual(2, deque.popBack())

    for i in 3..<11 {
      XCTAssertNil(deque.pushBack(i))
      XCTAssertFalse(deque.isEmpty)
    }

    for i in 3..<11 {
      XCTAssertFalse(deque.isEmpty)
      XCTAssertEqual(i, deque.popFront())
    }

    XCTAssert(deque.isEmpty)
  }

  func testDequeHeaderLayout() {
    let frontOffset = MemoryLayout.offset(of: \TaskDequeHeader<PosixConcurrencyPlatform>.front)!
    let backOffset = MemoryLayout.offset(of: \TaskDequeHeader<PosixConcurrencyPlatform>.back)!
    XCTAssertGreaterThan(
      backOffset - frontOffset,
      127,
      "Offsets too close and will result in false sharing! \(backOffset) - \(frontOffset)")
  }

  static var allTests = [
    ("testSimplePushAndPop", testSimplePushAndPop),
    ("testDequeHeaderLayout", testDequeHeaderLayout),
  ]
}
