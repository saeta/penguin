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

import XCTest

final class SwiftLanguageTests: XCTestCase {
  func testCopyChecker() {
    var cc = CopyChecker(3)
    XCTAssertEqual(3, cc.value)
    XCTAssertEqual(0, cc.copyCount)

    let c2 = cc
    XCTAssertEqual(3, cc.value)
    XCTAssertEqual(0, cc.copyCount)
    XCTAssertEqual(3, c2.value)
    XCTAssertEqual(0, c2.copyCount)

    cc.add(3)
    XCTAssertEqual(6, cc.value)
    XCTAssertEqual(1, cc.copyCount)
    XCTAssertEqual(3, c2.value)
    XCTAssertEqual(0, c2.copyCount)
  }

  func testInPlaceMutationsOfArrayOfTuples() {
    // Verifies that mutating methods on elements of tuples contained within an array does not
    // result in a bunch of extra copies being made.
    var arr = [(Int, CopyChecker)]()
    arr.append((1, CopyChecker(1)))
    arr.append((2, CopyChecker(2)))
    XCTAssertEqual(0, arr[0].1.copyCount)
    XCTAssertEqual(0, arr[1].1.copyCount)
    XCTAssertEqual(1, arr[0].1.value)
    XCTAssertEqual(2, arr[1].1.value)

    // The following occurs with zero copies made.
    arr[0].1.add(3)
    XCTAssertEqual(0, arr[0].1.copyCount)
    XCTAssertEqual(0, arr[1].1.copyCount)
    XCTAssertEqual(4, arr[0].1.value)
    XCTAssertEqual(2, arr[1].1.value)

    // The following causes copies in non-release builds, but not in optimized mode.

    // var modifyMe = arr[0]
    // modifyMe.1.add(4)
    // arr[0] = modifyMe
    // XCTAssertEqual(0, arr[0].1.copyCount)
    // XCTAssertEqual(0, arr[1].1.copyCount)
    // XCTAssertEqual(8, arr[0].1.value)
    // XCTAssertEqual(2, arr[1].1.value)
  }

  func testCopyCheckerWrapper() {
    // Verifies that _modify subscripts on tuples and arrays do not cause copies.
    var wrapper = CopyCheckerWrapper()
    XCTAssertEqual(0, wrapper.underlying[0].1.copyCount)
    XCTAssertEqual(0, wrapper.underlying[0].1.value)

    wrapper[0].add(3)
    XCTAssertEqual(3, wrapper.underlying[0].1.value)
    XCTAssertEqual(0, wrapper.underlying[0].1.copyCount)
  }

  func testArrayRemoveAllOrdering() {
    // Verifies that `Array.removeAll` processes elements in forward order.
    //
    // (This behavior is required for correctness in certain graph implementations.)
    var arr = Array(0..<10)

    var index = 0
    arr.removeAll { i in
      XCTAssertEqual(index, i)
      index += 1
      return false
    }
    XCTAssertEqual(Array(0..<10), arr)

    index = 0
    arr.removeAll { i in
      XCTAssertEqual(index, i)
      index += 1
      return true
    }
    XCTAssert(arr.isEmpty)

    arr = Array(0..<10)
    index = 0
    arr.removeAll { i in
      XCTAssertEqual(index, i)
      index += 1
      return i % 2 == 0
    }
    XCTAssertEqual([1, 3, 5, 7, 9], arr)
    index = 1
    arr.removeAll { i in
      XCTAssertEqual(index, i)
      index += 2
      return (i - 1) % 4 == 0
    }
    XCTAssertEqual([3, 7], arr)

    index = 3
    arr.removeAll { i in
      XCTAssertEqual(index, i)
      index += 4
      return true
    }

    arr = Array(0..<100000)
    index = 0
    arr.removeAll { i in
      XCTAssertEqual(index, i)
      index += 1
      return Bool.random()
    }
  }

  static var allTests = [
    ("testCopyChecker", testCopyChecker),
    ("testInPlaceMutationsOfArrayOfTuples", testInPlaceMutationsOfArrayOfTuples),
    ("testArrayRemoveAllOrdering", testArrayRemoveAllOrdering),
  ]
}

fileprivate class CopyCheckerHolder {
  var value: Int
  var copyCount: Int
  init(value: Int, copyCount: Int) {
    self.value = value
    self.copyCount = copyCount
  }
}

/// A value-semantic `Int`, backed by heap storage that also keeps track of the
fileprivate struct CopyChecker {
  private var holder: CopyCheckerHolder

  init(_ value: Int) {
    holder = CopyCheckerHolder(value: value, copyCount: 0)
  }

  var value: Int { holder.value }
  var copyCount: Int { holder.copyCount }

  mutating func add(_ value: Int) {
    ensureUniquelyReferenced()
    holder.value += value
  }

  mutating func ensureUniquelyReferenced() {
    if !isKnownUniquelyReferenced(&holder) {
      self.holder = CopyCheckerHolder(value: holder.value, copyCount: holder.copyCount + 1)
    }
  }
}

fileprivate struct CopyCheckerWrapper {
  var underlying: [(Int, CopyChecker)]

  init() {
    underlying = []
    underlying.append((0, CopyChecker(0)))
  }

  subscript(index: Int) -> CopyChecker {
    get { underlying[index].1 }
    _modify { yield &underlying[index].1 }
  }
}
