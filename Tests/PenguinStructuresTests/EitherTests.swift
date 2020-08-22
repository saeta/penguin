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

import XCTest
import PenguinStructures


class EitherTests: XCTestCase {
  let sorted0: [Either<Int, Int>] = [.a(1), .a(2), .a(1000), .b(-3), .b(0), .b(5)]
  let sorted1: [Either<String, Int>] = [.a(""), .a("abc"), .a("xyz"), .b(-4), .b(0), .b(10)]

  func testComparable() {
    // Also tests Equatable semantics
    do {
      for (a, (b, c)) in zip(sorted0, zip(sorted0.dropFirst(), sorted0.dropFirst(2))) {
        a.checkComparableSemantics(equal: a, greater: b, greaterStill: c)
      }
    }
    
    do {
      for (a, (b, c)) in zip(sorted1, zip(sorted1.dropFirst(), sorted1.dropFirst(2))) {
        a.checkComparableSemantics(equal: a, greater: b, greaterStill: c)
      }
    }
  }

  func testProperties() {
    let isA = Either<String, Int>.a("ayy")
    let isB = Either<String, Int>.b(3)
    XCTAssert(isA.a == "ayy")
    XCTAssert(isA.b == nil)
    XCTAssert(isB.a == nil)
    XCTAssert(isB.b == 3)
  }
  
  func testHashable() {
    // Also tests Equatable semantics
    for x in sorted0 { x.checkHashableSemantics() }
    for y in sorted1 { y.checkHashableSemantics() }
  }
  
  static var allTests = [
    ("testComparable", testComparable),
    ("testProperties", testProperties),
    ("testHashable", testHashable),
  ]
}

class EitherCollectionTests: XCTestCase {
  func testSequence() {
    typealias A = AnySequence<Int>
    let x = 0...10
    let y = x.reversed()

    Either<A, A>.a(A(x)).checkSequenceSemantics(expecting: x)
    Either<A, A>.b(A(y)).checkSequenceSemantics(expecting: y)
  }

  func testCollection() {
    typealias X = ClosedRange<Int>
    typealias Y = ReversedCollection<ClosedRange<Int>>
    let x: X = 0...10
    let y: Y = x.reversed()

    // Also tests Sequence semantics
    Either<X, Y>.a(x).checkCollectionSemantics(expecting: x)
    Either<X, Y>.b(y).checkCollectionSemantics(expecting: y)

    Either<Y, X>.b(x).checkCollectionSemantics(expecting: x)
    Either<Y, X>.a(y).checkCollectionSemantics(expecting: y)
  }
  
  static var allTests = [
    ("testSequence", testSequence),
    ("testCollection", testCollection),
  ]
}
