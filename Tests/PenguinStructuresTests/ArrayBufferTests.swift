//******************************************************************************
// Copyright 2020 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//    https://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//
import XCTest
import PenguinStructures

extension ArrayBuffer {
  static func test_init() {
    for n in 0..<100 {
      let s = Self(minimumCapacity: n)
      XCTAssertEqual(s.count, 0)
      XCTAssertGreaterThanOrEqual(s.capacity, n)
    }
  }
  
  /// tests deinit.
  ///
  /// Parameter newElement: given a tracking closure with semantics suitable for
  /// `Tracked`, returns a new element.
  static func test_deinit(_ newElement: (@escaping (Int)->Void)->Element) {
    var count = 0
    do {
      var s = Self(minimumCapacity: 100)
      for _ in 0..<100 { _ = s.append(newElement { count += $0 }) }
      XCTAssertEqual(count, 100) // sanity check
      XCTAssertEqual(s.count, 100)
    }
    XCTAssertEqual(
      count, 0,
      "deinit failed to deinitialize some stored elements."
    )
  }
}

class ArrayBufferTests: XCTestCase {
  typealias A<T> = ArrayBuffer<ArrayStorage<T>>
  
  func test_init() {
    A<Int>.test_init()
  }
  
  func test_deinit() {
    A<Tracked<Void>>.test_deinit { Tracked((), track: $0) }
  }
  
  func test_withUnsafeBufferPointer() {
    var s = A<Int>(minimumCapacity: 100)
    for i in 0..<100 { _ = s.append(i) }
    XCTAssert(s.withUnsafeBufferPointer { $0.elementsEqual(0..<100) })
  }
  
  func test_withUnsafeMutableBufferPointer() {
    var s = A<Int>(minimumCapacity: 100)
    for i in (0..<100).reversed() { _ = s.append(i) }
    XCTAssertFalse(s.withUnsafeBufferPointer { $0.elementsEqual(0..<100) })
    s.withUnsafeMutableBufferPointer { $0.sort() }
    XCTAssert(s.withUnsafeBufferPointer { $0.elementsEqual(0..<100) })
  }
  
  func test_append() {
    var trackCount = 0
    do {
      var s = A<Tracked<Int>>()
      var saveS = A<Tracked<Int>>()
      
      for i in 0..<100 {
        let oldCapacity = s.capacity
        XCTAssertEqual(s.count, i)
        XCTAssertEqual(trackCount, i)
        let oldSaveS = saveS
        
        let p = s.append(Tracked(i) { trackCount += $0 })

        XCTAssert(
          saveS.withUnsafeBufferPointer { a in
            oldSaveS.withUnsafeBufferPointer { b in
              a.elementsEqual(b)
            }})

        XCTAssertEqual(p, i)
        if p == oldCapacity {
          XCTAssertGreaterThanOrEqual(s.capacity, oldCapacity * 2)
        }
        XCTAssertLessThanOrEqual(s.count, s.capacity)
        XCTAssertEqual(s.count, i + 1)
        if i % 17 == 0 {
          // Test the path where the buffer isn't uniquely referenced
          saveS = s
        }
        XCTAssertEqual(s.withUnsafeBufferPointer { $0.last!.value }, i)
      }
      XCTAssert(
        s.withUnsafeBufferPointer { $0.map(\.value) }.elementsEqual(0..<100))
    }
    XCTAssertEqual(trackCount, 0)
  }
  
  static var allTests = [
    ("test_init", test_init),
    ("test_deinit", test_deinit),
    ("test_withUnsafeBufferPointer", test_withUnsafeBufferPointer),
    ("test_withUnsafeMutableBufferPointer", test_withUnsafeMutableBufferPointer),
    ("test_append", test_append),
  ]
}

