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

struct Pair<T,U> {
  var first: T
  var second: U
}

extension Pair: Equatable where T: Equatable, U: Equatable {}

struct Project1st<T,U>: Lens {
  static var focus: KeyPath<Pair<T, U>, T> { \.first }
}

struct MutablyProject2nd<T,U>: Lens {
  static var focus: WritableKeyPath<Pair<T, U>, U> { \.second }
}

fileprivate func pairs(_ x: Range<Int>) -> [Pair<Int,String>] {
  x.map { Pair(first: $0, second: String($0)) }
}
  
class ProjectionTests: XCTestCase {
  let base = pairs(0..<10)
  let replacementStrings = (0..<10).lazy.map(String.init).reversed()

  typealias P1 = Type<Project1st<Int, String>>
  typealias P2 = Type<MutablyProject2nd<Int, String>>
  
  func testSequenceSemantics() {
    AnySequence(base)[lens: P1()].checkSequenceSemantics(expecting: 0..<10)
  }
  
  func testCollectionSemantics() {
    AnyCollection(base)[lens: P1()].checkCollectionSemantics(expecting: 0..<10)
  }

  func testMutableCollectionSemantics() {
    var checkit = base[lens: P2()]
    checkit.checkMutableCollectionSemantics(writing: replacementStrings)
  }
  
  func testBidirectionalCollectionSemantics() {
    AnyBidirectionalCollection(base)[lens: P1()]
      .checkBidirectionalCollectionSemantics(expecting: 0..<10)
  }

  func testRandomAccessCollectionSemantics() {
    base[lens: P1()].checkRandomAccessCollectionSemantics(expecting: 0..<10)
  }

  func testLensSubscriptModify() {
    // get is covered in all the other tests.
    var target = base
    target[lens: P2()][0] += "suffix"
    XCTAssertEqual(target.first, Pair(first: 0, second: "0suffix"), "Mutation didn't write back.")
    XCTAssertEqual(target[1...], base[1...], "unexpected mutation")

    // Wholesale replacement through the projection replaces the whole target.
    let base2 = pairs(5..<10)
    target[lens: P2()] = base2[lens: P2()]
    XCTAssertEqual(target, base2)
  }
  
  static var allTests = [
    ("testSequenceSemantics", testSequenceSemantics),
    ("testCollectionSemantics", testCollectionSemantics),
    ("testMutableCollectionSemantics", testMutableCollectionSemantics),
    ("testBidirectionalCollectionSemantics", testBidirectionalCollectionSemantics),
    ("testRandomAccessCollectionSemantics", testRandomAccessCollectionSemantics),
    ("testLensSubscriptModify", testLensSubscriptModify),
  ]
}

