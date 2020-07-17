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

class AnyArrayBufferTests: XCTestCase {
  
  func test_init() {
    let a0 = ArrayBuffer(0...10)
    let b0 = AnyArrayBuffer(a0)
    XCTAssertEqual(a0.count, b0.count)
    XCTAssertEqual(a0.capacity, b0.capacity)
  }

  func test_mutate() {
    var a0 = AnyArrayBuffer(ArrayBuffer(10...30))

    let r = a0.mutate(ifElementType: Type<String>()) {  a1->Double in
      a1[0] += "X"
      return 3.14
    }
    XCTAssertEqual(
      r, nil, "Unexpectedly reported type match from non-matching buffer type")

    XCTAssertEqual(ArrayBuffer<Int>(a0)![0], 10)
    
    let baseAddress0 = a0.mutate(ifElementType: Type<Int>()) {
      a1->UnsafeMutablePointer<Int> in
      a1[0] += 1
      return a1.withUnsafeMutableBufferPointer { $0.baseAddress! }
    }
    XCTAssertNotEqual(
      baseAddress0, nil, "Unexpected failure to reconstruct buffer type.")
    XCTAssertEqual(ArrayBuffer<Int>(a0)![0], 11, "Mutation had no effect.")

    let baseAddress1 = a0.mutate(ifElementType: Type<Int>()) {
      a1->UnsafeMutablePointer<Int> in
      a1[0] += 1
      return a1.withUnsafeMutableBufferPointer { $0.baseAddress! }
    }
    XCTAssertEqual(
      baseAddress0, baseAddress1, "Expected no buffer reallocation.")
    XCTAssertEqual(ArrayBuffer<Int>(a0)![0], 12, "Mutation had no effect.")
    
    let a1 = a0
    a0.mutate(ifElementType: Type<Int>()) { $0[0] += 1 }
    XCTAssertEqual(ArrayBuffer<Int>(a0)![0], 13, "Mutation had no effect.")
    XCTAssertEqual(ArrayBuffer<Int>(a1)![0], 12, "Value semantics violated.")
  }

  func test_unsafelyMutate() {
    var a0 = AnyArrayBuffer(ArrayBuffer(10...30))

    XCTAssertEqual(ArrayBuffer<Int>(a0)![0], 10)
    
    let baseAddress0 = a0.unsafelyMutate(assumingElementType: Type<Int>()) {
      a1->UnsafeMutablePointer<Int> in
      a1[0] += 1
      return a1.withUnsafeMutableBufferPointer { $0.baseAddress! }
    }
    XCTAssertEqual(ArrayBuffer<Int>(a0)![0], 11, "Mutation had no effect.")

    let baseAddress1 = a0.unsafelyMutate(assumingElementType: Type<Int>()) {
      a1->UnsafeMutablePointer<Int> in
      a1[0] += 1
      return a1.withUnsafeMutableBufferPointer { $0.baseAddress! }
    }
    XCTAssertEqual(
      baseAddress0, baseAddress1, "Expected no buffer reallocation.")
    XCTAssertEqual(ArrayBuffer<Int>(a0)![0], 12, "Mutation had no effect.")
    
    let a1 = a0
    a0.unsafelyMutate(assumingElementType: Type<Int>()) { $0[0] += 1 }
    XCTAssertEqual(ArrayBuffer<Int>(a0)![0], 13, "Mutation had no effect.")
    XCTAssertEqual(ArrayBuffer<Int>(a1)![0], 12, "Value semantics violated.")
  }

  func test_AnyElementArrayBuffer() {
    XCTAssert(AnyElementArrayBuffer.self == AnyArrayBuffer<AnyObject>.self)
  }
  
  static var allTests = [
    ("test_init", test_init),
    ("test_mutate", test_mutate),
    ("test_unsafelyMutate", test_unsafelyMutate),
    ("test_AnyElementArrayBuffer", test_AnyElementArrayBuffer),
  ]
}
