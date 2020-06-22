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

extension ArrayStorage {
  static func test_emptyInit() {
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
      let s = Self((0..<100).map { _ in newElement { count += $0 } })
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

extension ArrayStorage where Element: Equatable {
  /// Tests `append`, or if `typeErased == true`, `appendValue(at:)`.
  static func test_append<Source: Collection>(source: Source)
    where Source.Element == Element
  {
    for n in 0..<source.count {
      let s = Self(minimumCapacity: n)
      
      for (i, e) in source.prefix(n).enumerated() {
        XCTAssertEqual(s.count, i)        
        let newPosition = s.append(e)
        XCTAssertEqual(newPosition, i)
        XCTAssertEqual(s.count, i + 1)
        XCTAssertEqual(s.last, e)
      }
      // Ensure we can fill up any remaining capacity
      while s.count < s.capacity {
        let newPosition = s.append(source.first!)
        XCTAssertEqual(newPosition, s.count - 1)
      }
      // Ensure that it properly reports that there is insufficient capacity.
      XCTAssertEqual(s.append(source.first!), nil)
    }
  }

  static func test_appending<Source: Collection>(source: Source)
    where Source.Element == Element
  {
    for n in 0..<(source.count + 2) {
      let s = Self(minimumCapacity: n)
      
      func doAppending(_ e: Element, moveElements: Bool) -> Self {
        let saveCapacity = s.capacity
        let saveCount = s.count
        let r = s.appending(e, moveElements: moveElements)
        if saveCount == saveCapacity {
          XCTAssertGreaterThanOrEqual(r.capacity, s.capacity * 2)
        }
        else {
          XCTAssertEqual(r.capacity, s.capacity)
        }
        XCTAssertEqual(s.count, moveElements ? 0 : saveCount)
        return r
      }
      
      for e in source.prefix(n) {
        _ = s.append(e)
      }
      let saveCount = s.count
      let s1 = doAppending(source.first!, moveElements: false)
      XCTAssertEqual(s.count, saveCount)
      
      XCTAssertEqual(s1.count, s.count + 1)
      XCTAssert(s1.dropLast().elementsEqual(s))
      XCTAssertEqual(s1.last, source.first)
      
      let s2 = doAppending(source.first!, moveElements: true)
      XCTAssert(s1.elementsEqual(s2))
    }
  }

  static func test_replacementStorage<Source: Collection>(source: Source)
    where Source.Element == Element
  {
    let s = Self(minimumCapacity: 0)
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

  static func test_copyingInit<Source: Collection>(source: Source)
    where Source.Element == Element
  {
    let s0 = Self(source)
    XCTAssert(s0.elementsEqual(source))
    XCTAssert(s0.capacity >= s0.count)
    
    let s1 = Self(source, minimumCapacity: source.count / 2)
    XCTAssert(s1.elementsEqual(source))
    XCTAssert(s1.capacity >= s1.count)

    let s2 = Self(source, minimumCapacity: source.count * 2)
    XCTAssert(s2.elementsEqual(source))
    XCTAssert(s2.capacity >= source.count * 2)
  }

  static func test_unsafeInitializingInit<Source: Collection>(source: Source)
    where Source.Element == Element
  {
    let a0 = Self(count: 0) { _ in }
    XCTAssertEqual(a0.count, 0)
    XCTAssertGreaterThanOrEqual(a0.capacity, a0.count)

    let a1 = Self(count: 0, minimumCapacity: 100) { _ in }
    XCTAssertEqual(a1.count, 0)
    XCTAssertGreaterThanOrEqual(a1.capacity, 100)

    let n = source.count
    let a2 = Self(count: n) { p in
      for (i, e) in source.enumerated() { (p + i).initialize(to: e) }
    }
    XCTAssert(a2.elementsEqual(source))
    XCTAssertGreaterThanOrEqual(a2.capacity, n)

    let a3 = Self(count: n, minimumCapacity: n * 2) { p in
      for (i, e) in source.enumerated() { (p + i).initialize(to: e) }
    }
    XCTAssert(a3.elementsEqual(source))
    XCTAssertGreaterThanOrEqual(a3.capacity, n * 2)
  }

  static func test_makeCopy<Source: Collection>(source: Source)
    where Source.Element == Element
  {
    for l in 0..<source.count {
      let content = source.prefix(l)
      for excess in 0..<3 {
        let s = Self(content, minimumCapacity: l + excess)
        let s1 = s.makeCopy()
        XCTAssertGreaterThanOrEqual(s1.capacity, s.capacity)
        s1.withUnsafeMutableBufferPointer {
          XCTAssert($0.elementsEqual(content))
        }
      }
    }    
  }
}


extension ArrayStorage where Element: Comparable {
  static func test_withUnsafeMutableBufferPointer<Source: Collection>(
    sortedSource: Source
  ) where Source.Element == Element {
    let s = Self(sortedSource.reversed())

    typealias TypedBuffer = UnsafeMutableBufferPointer<Element>
    
    func withBuffer<R>(_ body: (inout TypedBuffer)->R) -> R {
      XCTAssert(
        s.withUnsafeMutableBufferPointer { $0.elementsEqual(s) },
        "buffer view should match collection view."
      )
      return s.withUnsafeMutableBufferPointer(body)
    }
    
    XCTAssertFalse(withBuffer { $0.elementsEqual(sortedSource) })
    withBuffer { $0.sort() }
    XCTAssert(withBuffer { $0.elementsEqual(sortedSource) })
  }
}

class ArrayStorageTests: XCTestCase {
  func test_emptyInit() {
    ArrayStorage<Int>.test_emptyInit()
  }

  func test_append() {
    ArrayStorage<UInt8>.test_append(
      source: (0..<100).lazy.map { UInt8($0) })
  }

  func test_appending() {
    ArrayStorage<UInt8>.test_appending(
      source: (0..<20).lazy.map { UInt8($0) })
  }

  func test_withUnsafeMutableBufferPointer() {
    ArrayStorage<Int>.test_withUnsafeMutableBufferPointer(
      sortedSource: 99..<199)
  }
  
  func test_elementType() {
    let intStorage = ArrayStorage<Int>(minimumCapacity: 0)
    XCTAssert(type(of: intStorage).elementType == Int.self)
    let uintStorage = ArrayStorage<UInt>(minimumCapacity: 0)
    XCTAssert(type(of: uintStorage).elementType == UInt.self)
  }
  
  func test_replacementStorage() {
    ArrayStorage<Int>.test_replacementStorage(source: 0..<10)
  }
  
  func test_makeCopy() {
    ArrayStorage<Int>.test_makeCopy(source: 0..<10)
  }
  
  func test_deinit() {
    ArrayStorage<Tracked<()>>.test_deinit { Tracked((), track: $0) }
  }

  func test_copyingInit() {
    ArrayStorage<Int>.test_copyingInit(source: 0..<50)
  }

  func test_unsafeInitializingInit() {
    ArrayStorage<Int>.test_unsafeInitializingInit(source: 0..<100)
  }
  
  func test_collectionSemantics() {
    var s = ArrayStorage<Int>(0..<100)
    s.checkRandomAccessCollectionSemantics(expectedValues: 0..<100)
    s.checkMutableCollectionSemantics(source: 50..<150)
  }

  static var allTests = [
    ("test_emptyInit", test_emptyInit),
    ("test_append", test_append),
    ("test_appending", test_appending),
    ("test_withUnsafeMutableBufferPointer", test_withUnsafeMutableBufferPointer),
    ("test_elementType", test_elementType),
    ("test_elementType", test_elementType),
    ("test_replacementStorage", test_replacementStorage),
    ("test_deinit", test_deinit),
    ("test_copyingInit", test_copyingInit),
    ("test_unsafeInitializingInit", test_unsafeInitializingInit),
    ("test_collectionSemantics", test_collectionSemantics),
  ]
}
