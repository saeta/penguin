//******************************************************************************
// Copyright 2019 Google LLC
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

extension FixedSizeArray {
  /// Invokes `body` on the buffer resulting from prepending each element of
  /// `source`, in order, to `self`.
  func withPrependedBuffer<Source: Collection, R>(
    _ source: Source, _ body: (UnsafeBufferPointer<Element>)->R
  ) -> R
    where Source.Element == Element
  {
    return source.isEmpty ? withUnsafeBufferPointer(body)
      : self.prepending(source.first!)
          .withPrependedBuffer(source.dropFirst(), body)
  }
}

extension FixedSizeArray where Element: Comparable {
  func test_MutableCollection<Source: Collection>(_ sortedSource: Source)
    where Source.Element == Element
  {
    var me = self
    me.sort()
    XCTAssert(me.elementsEqual(self.sorted()))
    if sortedSource.isEmpty { return }
    self.prepending(sortedSource.first!)
      .test_MutableCollection(sortedSource.dropFirst())
  }
}

class FixedSizeArrayTests: XCTestCase {
  func test_initGeneric() {
    // We can initialize from any number of input collection types.
    let a1 = Array6(0..<6)
    let a2 = Array6(Array(0..<6))
    let a3 = Array6((0..<6).lazy.map { $0 })
    XCTAssertEqual(a1, a2)
    XCTAssertEqual(a1, a3)
  }

  func test_initRemoving() {
    let a1 = Array6(0..<6)
    for i in a1.indices {
      let a2 = Array5(a1, removingAt: i)
      XCTAssert(a2[..<i].elementsEqual(a1[..<i]))
      XCTAssert(a2[i...].elementsEqual(a1[(i + 1)...]))
    }
  }
  
  func test_inserting() {
    let a1 = Array5(0..<5)
    for i in 0...5 {
      let a2 = a1.inserting(9, at: i)
      XCTAssert(a2[..<i].elementsEqual(a1[..<i]))
      XCTAssertEqual(a2[i], 9)
      XCTAssert(a2[(i + 1)...].elementsEqual(a1[i...]))
    }
  }

  func test_withUnsafeBufferPointer() {
    let a1 = Array6(0..<6)
    XCTAssert(a1.withUnsafeBufferPointer { $0.elementsEqual(0..<6) })
  }
  
  func test_withUnsafeMutableBufferPointer() {
    var a1 = Array6(0..<6)
    XCTAssert(a1.withUnsafeMutableBufferPointer { $0.elementsEqual(0..<6) })
    a1.withUnsafeMutableBufferPointer { p in
      for (i, e) in zip(p.indices, (0..<6).reversed()) {
        p[i] = e
      }
    }
    XCTAssert(a1.elementsEqual((0..<6).reversed()))
  }

  func test_prepending() {
    XCTAssert(
      Array0<Int>().withPrependedBuffer(0..<20) {
        $0.elementsEqual((0..<20).reversed())
      })
  }

  func test_MutableCollection() {
    // This test exercises startIndex, endIndex, and subscript.
    Array0<Int>().test_MutableCollection(0..<20)
  }
  
  func test_general() {
    let x = Array6(0..<6)
    XCTAssert(x.elementsEqual(0..<6))
    XCTAssertEqual(x, .init(0..<6))
    XCTAssertLessThan(x, .init(1..<7))

    for i in x.indices {
      // Test removing at each position
      let d = x.removing(at: i)
      XCTAssert(d.elementsEqual([x[..<i], x[(i+1)...]].joined()))

      // Test insertion at each position
      
      // A 1-element slice of d, but with x[i] as its only element.  
      let xi = d.removing(at: 0).prepending(x[i])[0...0]

      // Try reinserting the element 1 place further along (wrapping to count).
      let j = (i + 1) % d.count
      let e = d.inserting(x[i], at: j)
      XCTAssert(e.elementsEqual([d[..<j], xi, d[j...]].joined()))

      XCTAssert(type(of: x) == type(of: e))
    }
  }
  
  static var allTests = [
    ("test_initGeneric", test_initGeneric),
    ("test_initRemoving", test_initRemoving),
    ("test_inserting", test_inserting),
    ("test_withUnsafeBufferPointer", test_withUnsafeBufferPointer),
    ("test_withUnsafeMutableBufferPointer", test_withUnsafeMutableBufferPointer),
    ("test_prepending", test_prepending),
    ("test_MutableCollection", test_MutableCollection),
    ("test_general", test_general),
  ]
}

