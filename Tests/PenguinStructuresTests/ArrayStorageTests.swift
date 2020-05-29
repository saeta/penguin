//******************************************************************************
// Copyright 2020 Penguin Authors
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

// Reusable test implementations

extension ArrayStorageImplementation {
  static func test_create() {
    for n in 0..<100 {
      let s = Self.create(minimumCapacity: n)
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
      let s = Self.create(minimumCapacity: 100)
      for _ in 0..<100 { _ = s.append(newElement { count += $0 }) }
      XCTAssertEqual(count, 100) // sanity check

      // Keep s alive until we've tested count above
      XCTAssertEqual(s.count, 100)
    }
    XCTAssertEqual(
      count, 0,
      "deinit failed to deinitialize some stored elements."
    )
  }
}

extension ArrayStorageImplementation where Element: Equatable {
  /// Tests `append`, or if `typeErased == true`, `appendValue(at:)`.
  static func test_append<Source: Collection>(
    source: Source, typeErased: Bool = false
  )
    where Source.Element == Element
  {
    for n in 0..<source.count {
      let s = Self.create(minimumCapacity: n)
      
      func doAppend(_ e: Element) -> Int? {
        typeErased
          ? withUnsafePointer(to: e) { s.appendValue(at: .init($0)) }
          : s.append(e)
      }
      
      for (i, e) in source.prefix(n).enumerated() {
        XCTAssertEqual(s.count, i)        
        let newPosition = doAppend(e)
        XCTAssertEqual(newPosition, i)
        XCTAssertEqual(s.count, i + 1)
        XCTAssertEqual(s.withUnsafeMutableBufferPointer { $0.last }, e)
      }
      // Ensure we can fill up any remaining capacity
      while s.count < s.capacity {
        let newPosition = doAppend(source.first!)
        XCTAssertEqual(newPosition, s.count - 1)
      }
      // Ensure that it properly reports that there is insufficient capacity.
      XCTAssertEqual(doAppend(source.first!), nil)
    }
  }

  /// Tests `appending`, or if `typeErased == true`, `appendingValue(at:)`.
  static func test_appending<Source: Collection>(
    source: Source, typeErased: Bool = false
  )
    where Source.Element == Element
  {
    for n in 0..<(source.count + 2) {
      let s = Self.create(minimumCapacity: n)
      
      func doAppending(_ e: Element, moveElements: Bool) -> Self {
        let saveCapacity = s.capacity
        let saveCount = s.count
        let r = typeErased
          ? withUnsafePointer(to: e) {
            s.appendingValue(at: .init($0), moveElements: moveElements)
          }
          : s.appending(e, moveElements: moveElements)
        if saveCount == saveCapacity {
          XCTAssertGreaterThanOrEqual(r.capacity, s.capacity * 2)
        }
        else {
          XCTAssertEqual(r.capacity, s.capacity)
        }
        return r
      }
      
      for e in source.prefix(n) {
        _ = s.append(e)
      }
      let saveCount = s.count
      let s1 = doAppending(source.first!, moveElements: false)
      XCTAssertEqual(s.count, saveCount)
      
      s.withUnsafeMutableBufferPointer { b in
        s1.withUnsafeMutableBufferPointer { b1 in
          XCTAssertEqual(b1.count, b.count + 1)
          XCTAssert(b1.dropLast().elementsEqual(b))
          XCTAssertEqual(b1.last, source.first)
        }
      }
      
      let s2 = doAppending(source.first!, moveElements: true)
      
      s1.withUnsafeMutableBufferPointer { b1 in
        s2.withUnsafeMutableBufferPointer { b2 in
          XCTAssert(b1.elementsEqual(b2))
        }
      }
    }
  }

  static func test_replacementStorage<Source: Collection>(source: Source)
    where Source.Element == Element
  {
    let s = Self.create(minimumCapacity: 0)
    let oldBaseAddress = s.withUnsafeMutableBufferPointer { $0.baseAddress! }
    for m in 0..<source.count {
      var newBaseAddress: UnsafeMutablePointer<Element>?

      let r = s.replacementStorage(count: m, minimumCapacity: m) {
        oldBase, newBase in
        XCTAssertEqual(oldBase, oldBaseAddress)
        newBaseAddress = newBase
        for (i, x) in source.prefix(m).enumerated() {
          (newBase + i).initialize(to: x)
        }
      }
      XCTAssertEqual(
        newBaseAddress, r.withUnsafeMutableBufferPointer { $0.baseAddress! })
      XCTAssertEqual(r.count, m)
      XCTAssertGreaterThanOrEqual(r.capacity, m)
    }
  }
}

extension ArrayStorageImplementation where Element: Comparable {
  /// Tests `withUnsafeMutableBufferPointer`, or if `raw == true`,
  /// `withUnsafeMutableRawBufferPointer`.
  static func test_withUnsafeMutableBufferPointer<Source: Collection>(
    sortedSource: Source, raw: Bool = false
  ) where Source.Element == Element {
    let s = Self.create(minimumCapacity: sortedSource.count)
    for i in sortedSource.reversed() { _ = s.append(i) }

    typealias TypedBuffer = UnsafeMutableBufferPointer<Element>
    
    func withBuffer<R>(_ body: (inout TypedBuffer)->R) -> R {
      return raw
        ? s.withUnsafeMutableRawBufferPointer { rawBuffer in
          var b = TypedBuffer(
            start: rawBuffer.baseAddress?.assumingMemoryBound(to: Element.self),
            count: rawBuffer.count / MemoryLayout<Element>.stride)
          return body(&b)
        }
        : s.withUnsafeMutableBufferPointer(body)
    }
    
    XCTAssertFalse(withBuffer { $0.elementsEqual(sortedSource) })
    withBuffer { $0.sort() }
    XCTAssert(withBuffer { $0.elementsEqual(sortedSource) })
  }
}

class ArrayStorageTests: XCTestCase {
  func test_create() {
    ArrayStorage<Int>.test_create()
  }

  func test_append() {
    ArrayStorage<UInt8>.test_append(
      source: (0..<100).lazy.map { UInt8($0) })
  }

  func test_appending() {
    ArrayStorage<UInt8>.test_appending(
      source: (0..<20).lazy.map { UInt8($0) })
  }

  func test_typeErasedAppend() {
    ArrayStorage<UInt8>.test_append(
      source: (0..<100).lazy.map { UInt8($0) }, typeErased: true)
  }

  func test_typeErasedAppending() {
    ArrayStorage<UInt8>.test_appending(
      source: (0..<20).lazy.map { UInt8($0) }, typeErased: true)
  }

  func test_withUnsafeMutableBufferPointer() {
    ArrayStorage<Int>.test_withUnsafeMutableBufferPointer(
      sortedSource: 99..<199)
  }
  
  func test_withUnsafeMutableRawBufferPointer() {
    ArrayStorage<Int>.test_withUnsafeMutableBufferPointer(
      sortedSource: 99..<199, raw: true)
  }
  
  func test_replacementStorage() {
    ArrayStorage<Int>.test_replacementStorage(source: 0..<10)
  }
  
  func test_deinit() {
    ArrayStorage<Tracked<()>>.test_deinit { Tracked((), track: $0) }
  }

  static var allTests = [
    ("test_create", test_create),
    ("test_append", test_append),
    ("test_appending", test_appending),
    ("test_typeErasedAppend", test_typeErasedAppend),
    ("test_typeErasedAppending", test_typeErasedAppending),
    ("test_withUnsafeMutableBufferPointer", test_withUnsafeMutableBufferPointer),
    (
      "test_withUnsafeMutableRawBufferPointer",
     test_withUnsafeMutableRawBufferPointer),
    ("test_elementType", test_elementType),
    ("test_replacementStorage", test_replacementStorage),
    ("test_deinit", test_deinit),
  ]
}
