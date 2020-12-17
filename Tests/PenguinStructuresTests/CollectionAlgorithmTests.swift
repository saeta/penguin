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

  func testWritePrefixIterator() {
    var a = Array(0..<10)
    
    do {
      let empty = 99..<99
      var i = empty.makeIterator()
      let (writtenCount, afterLastWritten) = a.writePrefix(from: &i)
      XCTAssert(a.elementsEqual(0..<10))
      XCTAssertEqual(writtenCount, empty.count)
      XCTAssertEqual(afterLastWritten, a.index(atOffset: writtenCount))
    }

    do {
      let underflow = 1..<10
      var i = underflow.makeIterator()
      let (writtenCount, afterLastWritten) = a.writePrefix(from: &i)
      XCTAssert(a.dropLast().elementsEqual(underflow))
      XCTAssertEqual(writtenCount, underflow.count)
      XCTAssertEqual(afterLastWritten, a.index(atOffset: writtenCount))
    }

    do {
      let match = 21...30
      var i = match.makeIterator()
      let (writtenCount, afterLastWritten) = a.writePrefix(from: &i)
      XCTAssert(a.elementsEqual(match))
      XCTAssertEqual(writtenCount, a.count)
      XCTAssertEqual(afterLastWritten, a.index(atOffset: writtenCount))
    }

    do {
      let overflow = 31...41
      var i = overflow.makeIterator()
      let (writtenCount, afterLastWritten) = a.writePrefix(from: &i)
      XCTAssert(a.elementsEqual(overflow.dropLast()))
      XCTAssertEqual(writtenCount, a.count)
      XCTAssertEqual(afterLastWritten, a.index(atOffset: writtenCount))
      XCTAssertEqual(i.next(), 41, "unwritten element consumed")
    }

    do {
      a.removeAll()
      var i = (2..<99).makeIterator()
      let (writtenCount, afterLastWritten) = a.writePrefix(from: &i)
      XCTAssert(a.isEmpty)
      XCTAssertEqual(writtenCount, a.count)
      XCTAssertEqual(afterLastWritten, a.index(atOffset: writtenCount))
      XCTAssertEqual(i.next(), 2, "unwritten element consumed")
    }
  }
  
  func testWritePrefixCollection() {
    var a = Array(0..<10)

    do {
      let empty = 99..<99
      let (writtenCount, afterLastWritten, afterLastRead) = a.writePrefix(from: empty)
      XCTAssert(a.elementsEqual(0..<10))
      XCTAssertEqual(writtenCount, empty.count)
      XCTAssertEqual(afterLastWritten, a.index(atOffset: writtenCount))
      XCTAssertEqual(afterLastRead, empty.index(atOffset: writtenCount))
    }

    do {
      let underflow = 1..<10
      let (writtenCount, afterLastWritten, afterLastRead) = a.writePrefix(from: underflow)
      XCTAssert(a.dropLast().elementsEqual(underflow))
      XCTAssertEqual(writtenCount, underflow.count)
      XCTAssertEqual(afterLastWritten, a.index(atOffset: writtenCount))
      XCTAssertEqual(afterLastRead, underflow.index(atOffset: writtenCount))
    }
    
    do {
      let match = 1...10
      let (writtenCount, afterLastWritten, afterLastRead) = a.writePrefix(from: match)
      XCTAssert(a.elementsEqual(match))
      XCTAssertEqual(writtenCount, a.count)
      XCTAssertEqual(afterLastWritten, a.index(atOffset: writtenCount))
      XCTAssertEqual(afterLastRead, match.index(atOffset: writtenCount))
    }

    do {
      let overflow = 1...11
      let (writtenCount, afterLastWritten, afterLastRead) = a.writePrefix(from: overflow)
      XCTAssert(a.elementsEqual(overflow.dropLast()))
      XCTAssertEqual(writtenCount, a.count)
      XCTAssertEqual(afterLastWritten, a.index(atOffset: writtenCount))
      XCTAssertEqual(afterLastRead, overflow.index(atOffset: writtenCount))
    }

    do {
      a.removeAll()
      let overflow = 2..<99
      let (writtenCount, afterLastWritten, afterLastRead) = a.writePrefix(from: overflow)
      XCTAssert(a.isEmpty)
      XCTAssertEqual(writtenCount, a.count)
      XCTAssertEqual(afterLastWritten, a.index(atOffset: writtenCount))
      XCTAssertEqual(afterLastRead, overflow.index(atOffset: writtenCount))
    }
  }

  func testUpdateWhile() {
    var a = Array(0..<20)
    let p = a.update {
      if $0 >= 10 { return false }
      $0 += 100
      return true
    }
    XCTAssertEqual(a[..<p], Array(100..<110)[...])
    XCTAssertEqual(a[p...], Array(10..<20)[...])

    var i = 0
    let q = a.update { $0 = i; i += 1; return true }
    XCTAssertEqual(q, a.endIndex)
    XCTAssertEqual(a, Array(0..<20))
  }

  func testUpdateAll() {
    var a = Array(0..<20)
    a.updateAll { $0 *= 2 }
    XCTAssertEqual(a, (0..<20).map { $0 * 2 })
  }
  
  func testAssignSequence() {
    var a = Array(0..<0)
    var n = a.assign(AnySequence(1..<1))
    XCTAssertEqual(n, 0)
    XCTAssertEqual(a, Array(0..<0))

    a = Array(0..<10)
    n = a.assign(AnySequence(10..<20))
    XCTAssertEqual(n, a.count)
    XCTAssertEqual(a, Array(10..<20))
  }
  
  func testAssignCollection() {
    var a = Array(0..<0)
    var n = a.assign(1..<1)
    XCTAssertEqual(n, 0)
    XCTAssertEqual(a, Array(0..<0))

    a = Array(0..<10)
    n = a.assign(10..<20)
    XCTAssertEqual(n, a.count)
    XCTAssertEqual(a, Array(10..<20))
  }

  func testIndexAtOffset() {
    let src = (1..<13).reversed()
    for i in 0..<src.count {
      XCTAssertEqual(src.index(atOffset: i), src.index(src.startIndex, offsetBy: i))
    }
  }
  
  static var allTests = [
    ("testHalfStablePartitionEmptyDelayIndices", testHalfStablePartitionEmptyDelayIndices),
    ("testHalfStablePartitionConsecutiveIndices", testHalfStablePartitionConsecutiveIndices),
    ("testHalfStablePartitionEmptyData", testHalfStablePartitionEmptyData),
    ("testHalfStablePartitionByIndicesConsecutiveThroughEnd", testHalfStablePartitionByIndicesConsecutiveThroughEnd),
    ("testWritePrefixIterator", testWritePrefixIterator),
    ("testWritePrefixCollection", testWritePrefixCollection),
    ("testAssignSequence", testAssignSequence),
    ("testAssignCollection", testAssignCollection),
    ("testIndexAtOffset", testIndexAtOffset),
  ]
}
