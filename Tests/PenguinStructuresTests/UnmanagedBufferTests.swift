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

@testable import PenguinStructures
import XCTest

final class UnmanagedBufferTests: XCTestCase {
  func testOffsetAndAlignments() {
    assert(header: Void.self, elements: Int.self, capacity: 10, totalBytes: 80, elementsOffset: 0, alignment: 8)
    assert(header: Int.self, elements: Void.self, capacity: 10, totalBytes: 18, elementsOffset: 8, alignment: 8)
    assert(header: Int.self, elements: Int.self, capacity: 10, totalBytes: 88, elementsOffset: 8, alignment: 8)
    assert(header: (Int, Int32).self, elements: Int.self, capacity: 10, totalBytes: 96, elementsOffset: 16, alignment: 8)
    assert(header: Int32.self, elements: (Int.self), capacity: 10, totalBytes: 88, elementsOffset: 8, alignment: 8)
  }

  func testMemoryReclaiming() {
    var trackCount = 0
    var buffer = UnmanagedBuffer<Tracked<Int>, Int>(capacity: 3) { _ in
      // Don't initialize elements.
      Tracked(3) { trackCount += $0 }
    }
    XCTAssertEqual(1, trackCount)
    buffer.deallocate { _, _ in }  // No need to de-initalize.
    XCTAssertEqual(0, trackCount)
  }

  func testStoringAndRetrievingElements() {
    var trackCount = 0
    var buffer = UnmanagedBuffer<Bool, Tracked<UInt>>(capacity: 10) { buff in
      for i in 0..<buff.count {
        (buff.baseAddress! + i).initialize(to: Tracked(UInt(i)) { trackCount += $0 })
      }
      return true
    }
    XCTAssert(buffer.header)
    XCTAssertEqual(trackCount, 10)
    for i in 0..<10 {
      XCTAssertEqual(buffer[i].value, UInt(i))
    }
    buffer.deallocate { buff, _ in
      buff.baseAddress!.deinitialize(count: buff.count)
    }
    XCTAssertEqual(0, trackCount)
  }

  static var allTests = [
    ("testOffsetAndAlignments", testOffsetAndAlignments),
    ("testMemoryReclaiming", testMemoryReclaiming),
    ("testStoringAndRetrievingElements", testStoringAndRetrievingElements),
  ]
}

fileprivate func assert<H, E>(
  header: H.Type,
  elements: E.Type,
  capacity: Int,
  totalBytes: Int,
  elementsOffset: Int,
  alignment: Int,
  file: StaticString = #file,
  line: UInt = #line
) {
  let results = UnmanagedBuffer<H, E>.offsetsAndAlignments(capacity: capacity)
  XCTAssertEqual(results.totalBytes, totalBytes,
    "Incorrect total bytes; expected: \(totalBytes), computed: \(results.totalBytes)",
    file: file, line: line)
  XCTAssertEqual(results.elementsOffset, elementsOffset,
    "Incorrect elements offset; expected: \(elementsOffset), computed: \(results.elementsOffset)",
    file: file, line: line)
  XCTAssertEqual(results.bufferAlignment, alignment,
    "Incorrect buffer alignment; expected: \(alignment), computed: \(results.bufferAlignment)",
    file: file, line: line)
}
