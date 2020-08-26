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

import PenguinTesting
import PenguinStructures
import XCTest

fileprivate protocol P {}
extension Double: P {}

fileprivate class Base {}
fileprivate class Derived: Base {}

final class AnyValueTests: XCTestCase {
  // A type that will not fit in existential inline storage.
  typealias BufferOverflow = (Int, Int, Int, Int)

  // A value that will not fit in existential inline storage.
  let bufferOverflow = (1, 2, 3, 4)
  
  func test_Int() {
    var a = AnyValue(3)
    XCTAssert(a.storedType == Int.self)
    XCTAssertEqual(a[Type<Int>()], 3)
    XCTAssertEqual(a[unsafelyAssuming: Type<Int>()], 3)
    
    a[Type<Int>()] += 1
    XCTAssertEqual(a[Type<Int>()], 4)
    XCTAssertEqual(a.boxOrObjectID, nil)
    
    a[unsafelyAssuming: Type<Int>()] += 1
    XCTAssertEqual(a[Type<Int>()], 5)
  }
  
  func test_String() {
    var a = AnyValue("Three")
    XCTAssert(a.storedType == String.self)
    XCTAssertEqual(a[Type<String>()], "Three")
    XCTAssertEqual(a[unsafelyAssuming: Type<String>()], "Three")

    a[Type<String>()].append("D")
    XCTAssertEqual(a[Type<String>()], "ThreeD")

    // I don't know how big String is off the top of my head.
    let inlineStorageExpected = MemoryLayout<String>.size < 3 * MemoryLayout<Int>.size
      && MemoryLayout<String>.alignment <= MemoryLayout<Any>.alignment
    
    if inlineStorageExpected {
      XCTAssertNil(a.boxOrObjectID)
    } else {
      XCTAssertNotNil(a.boxOrObjectID)
    }
  }

  func test_BufferOverflow() {
    var a = AnyValue(bufferOverflow)
    XCTAssert(a.storedType == type(of: bufferOverflow))
    XCTAssert(a[Type<BufferOverflow>()] == bufferOverflow)
    XCTAssert(a[unsafelyAssuming: Type<BufferOverflow>()] == bufferOverflow)
    
    let boxID = a.boxOrObjectID
    XCTAssertNotNil(boxID)
    
    a[Type<BufferOverflow>()].0 += 42
    XCTAssert(a[Type<BufferOverflow>()] == (43, 2, 3, 4))
    XCTAssertEqual(a.boxOrObjectID, boxID, "Unexpected reallocation of box")
  }

  func test_class() {
    let base = Base()
    var a = AnyValue(base)
    XCTAssert(a.storedType == type(of: base))
    XCTAssert(a[Type<Base>()] === base)
    XCTAssert(a[unsafelyAssuming: Type<Base>()] === base)
    XCTAssertEqual(a.boxOrObjectID, ObjectIdentifier(base))
    
    let otherBase = Base()
    XCTAssert(otherBase !== base)
    a[Type<Base>()] = otherBase
    XCTAssert(a[Type<Base>()] === otherBase)
    XCTAssertEqual(a.boxOrObjectID, ObjectIdentifier(otherBase))
  }
  
  func testUpcastedSource() {
    // test postconditions storing a derived class instance as base.
    let derived = Derived() as Base
    var a = AnyValue(derived)
    XCTAssert(a.storedType == Base.self)
    XCTAssert(a[Type<Base>()] === derived)

    // test postconditions when storing an existential.
    a = AnyValue(Double.pi as P)
    XCTAssert(a.storedType == P.self)
    XCTAssertEqual(a[Type<P>()] as? Double, .pi)
  }

  func test_store() {
    var a = AnyValue(3)
    XCTAssertEqual(a.boxOrObjectID, nil)
    a.store(4)
    XCTAssertEqual(a[Type<Int>()], 4, "store didn't update the stored int")
    XCTAssertEqual(a.boxOrObjectID, nil)
    
    var bufferOverflow = self.bufferOverflow
    a.store(bufferOverflow)
    let boxID = a.boxOrObjectID
    XCTAssertNotEqual(boxID, nil, "BufferOverflow is too big, but apparently is stored inline.")
    XCTAssert(
      a[Type<BufferOverflow>()] == bufferOverflow, "store didn't update stored BufferOverflow")

    bufferOverflow.0 += 43
    a.store(bufferOverflow)
    XCTAssert(
      a[Type<BufferOverflow>()] == bufferOverflow,
      "store didn't correctly update stored BufferOverflow")
    
    XCTAssertEqual(a.boxOrObjectID, boxID, "store didn't reuse the box")
    let b = a
    XCTAssertEqual(
      b.boxOrObjectID, a.boxOrObjectID,
      "copies of boxed values unexpectedly don't share a box using CoW")
    a = AnyValue(bufferOverflow)
    XCTAssertNotEqual(
      a.boxOrObjectID, boxID,
      "Using store is no better than assigning over it with a new Any?")
    withExtendedLifetime(b) {}
  }

  func staticType<T>(of _: T) -> Any.Type { T.self }
  
  func test_asAny() {
    var a = AnyValue(3)
    let aInt = a.asAny
    XCTAssert(staticType(of: aInt) == Any.self)
    XCTAssertEqual(aInt as? Int, 3)

    a.store(bufferOverflow)
    let aBufferOverflow = a.asAny
    XCTAssert(aBufferOverflow is BufferOverflow)
    if aBufferOverflow is BufferOverflow {
      XCTAssert(aBufferOverflow as! BufferOverflow == bufferOverflow)
    }

    let base = Base()
    a.store(base)
    let aBase = a.asAny
    XCTAssert(aBase as? Base === base)
  }

  func test_inlineValueSemantics() {
    var a = AnyValue(3)
    var b = a
    a[Type<Int>()] += 1
    XCTAssertEqual(a[Type<Int>()], 4)
    XCTAssertEqual(b[Type<Int>()], 3, "value semantics of stored Int not preserved by subscript.")
    b = a
    a.store(9)
    XCTAssertEqual(a[Type<Int>()], 9)
    XCTAssertEqual(b[Type<Int>()], 4, "value semantics of stored Int not preserved by store()")
  }

  func test_boxedValueSemantics() {
    var a = AnyValue(bufferOverflow)
    var b = a
    a[Type<BufferOverflow>()].0 += 41
    XCTAssertEqual(a[Type<BufferOverflow>()].0, 42)
    XCTAssertEqual(
      b[Type<BufferOverflow>()].0, 1, "value semantics of boxed value not preserved by subscript.")
    b = a
    a.store((4, 3, 2, 1))
    XCTAssert(a[Type<BufferOverflow>()] == (4, 3, 2, 1))
    XCTAssert(
      b[Type<BufferOverflow>()] == (42, 2, 3, 4),
      "value semantics of boxed value not preserved by store()")
  }

  static let allTests = [
    ("test_Int", test_Int),
    ("test_String", test_String),
    ("test_BufferOverflow", test_BufferOverflow),
    ("test_class", test_class),
    ("testUpcastedSource", testUpcastedSource),
    ("test_store", test_store),
    ("test_asAny", test_asAny),
    ("test_inlineValueSemantics", test_inlineValueSemantics),
    ("test_boxedValueSemantics", test_boxedValueSemantics),
  ]
}
