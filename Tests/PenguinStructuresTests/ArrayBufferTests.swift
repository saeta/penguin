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

extension ArrayBuffer where Element: Equatable {
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
}

class ArrayBufferTests: XCTestCase {
  typealias A<T> = ArrayBuffer<T>
  
  func test_init() {
    A<Int>.test_init()
  }
  
  func test_copyingInit() {
    A<Int>.test_copyingInit(source: 0..<100)
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
    
    let forward = 0..<100
    let reverse = forward.reversed()
    for i in forward { _ = s.append(i) }
    // Sanity check
    XCTAssert(s.withUnsafeBufferPointer { $0.elementsEqual(forward) })
    
    // Remember address so we can verify non-reallocation
    let saveBaseAddress = s.withUnsafeBufferPointer { $0.baseAddress }
    
    s.withUnsafeMutableBufferPointer { $0.sort(by: >) }
    XCTAssert(s.withUnsafeBufferPointer { $0.elementsEqual(reverse) })
    
    XCTAssertEqual(
      s.withUnsafeBufferPointer { $0.baseAddress }, saveBaseAddress,
      "supposedly uniquely-referenced buffer was reallocated.")

    // Test the path where the buffer isn't uniquely-referenced.
    let saveS = s
    s.withUnsafeMutableBufferPointer { $0.sort(by: <) }
    XCTAssert(
      saveS.withUnsafeBufferPointer { $0.elementsEqual(reverse) },
      "value semantic failure: supposedly logically distinct copy modified."
    )
    
    XCTAssert(
      s.withUnsafeBufferPointer { $0.elementsEqual(forward) },
      "failure to modify instance with multiply-referenced buffer."
    )
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

func test_collectionSemantics() {
    var b = ArrayBuffer<Int>(0..<100)
    b.checkRandomAccessCollectionSemantics(expecting: 0..<100)
    b.checkMutableCollectionSemantics(writing: 50..<150)

    // Exercise the new tests.
    b.checkDeclaredSequenceRefinementSemantics(expecting: Array(b))
  }

  func test_storageInit() {
    let source = 0...66
    let s = ArrayStorage<Int>(source)
    let a = ArrayBuffer(s)
    XCTAssert(a.elementsEqual(source))
  }
  
  func test_unsafeInitializingInit() {
    typealias A = ArrayBuffer<Int>
    let source = 0...22
    
    let a0 = A(count: 0) { _ in }
    XCTAssertEqual(a0.count, 0)
    XCTAssertGreaterThanOrEqual(a0.capacity, a0.count)

    let a1 = A(count: 0, minimumCapacity: 100) { _ in }
    XCTAssertEqual(a1.count, 0)
    XCTAssertGreaterThanOrEqual(a1.capacity, 100)

    let n = source.count
    let a2 = A(count: n) { p in
      for (i, e) in source.enumerated() { (p + i).initialize(to: e) }
    }
    XCTAssert(a2.elementsEqual(source))
    XCTAssertGreaterThanOrEqual(a2.capacity, n)

    let a3 = A(count: n, minimumCapacity: n * 2) { p in
      for (i, e) in source.enumerated() { (p + i).initialize(to: e) }
    }
    XCTAssert(a3.elementsEqual(source))
    XCTAssertGreaterThanOrEqual(a3.capacity, n * 2)
  }
  
  static var allTests = [
    ("test_init", test_init),
    ("test_copyingInit", test_copyingInit),
    ("test_deinit", test_deinit),
    ("test_withUnsafeBufferPointer", test_withUnsafeBufferPointer),
    ("test_withUnsafeMutableBufferPointer", test_withUnsafeMutableBufferPointer),
    ("test_append", test_append),
    ("test_collectionSemantics", test_collectionSemantics),
    ("test_storageInit", test_storageInit),
    ("test_unsafeInitializingInit", test_unsafeInitializingInit),
  ]
}

