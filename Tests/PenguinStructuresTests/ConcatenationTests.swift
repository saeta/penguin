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

import PenguinStructures
import XCTest

final class ConcatenationTests: XCTestCase {

  func testInit() {
    XCTAssert(Concatenation(0..<10, 10..<20).elementsEqual(0..<20))
  }

  func testJoined() {
    XCTAssert((0..<10).joined(to: 10..<20).elementsEqual(0..<20))
  }

  func testConditionalConformances() {
    let a3 = 0..<10, b3 = 10..<20, joined = 0..<20
    let a2 = AnyBidirectionalCollection(a3), b2 = AnyBidirectionalCollection(b3)
    let a1 = AnyCollection(a3), b1 = AnyCollection(b3)
    let j11 = a1.joined(to: b1)
    XCTAssertFalse(j11.isBidirectional)
    j11.checkCollectionSemantics(expectedValues: joined)

    let j12 = a1.joined(to: b2)
    XCTAssertFalse(j12.isBidirectional)
    j12.checkCollectionSemantics(expectedValues: joined)

    let j13 = a1.joined(to: b3)
    XCTAssertFalse(j13.isBidirectional)
    j13.checkCollectionSemantics(expectedValues: joined)

    let j21 = a2.joined(to: b1)
    XCTAssertFalse(j21.isBidirectional)
    j21.checkCollectionSemantics(expectedValues: joined)

    let j22 = a2.joined(to: b2)
    XCTAssert(j22.isBidirectional)
    XCTAssertFalse(j22.isRandomAccess)
    j22.checkBidirectionalCollectionSemantics(expectedValues: joined)

    let j23 = a2.joined(to: b3)
    XCTAssert(j23.isBidirectional)
    XCTAssertFalse(j23.isRandomAccess)
    j23.checkBidirectionalCollectionSemantics(expectedValues: joined)

    let j31 = a3.joined(to: b1)
    XCTAssertFalse(j31.isBidirectional)
    j31.checkCollectionSemantics(expectedValues: joined)

    let j32 = a3.joined(to: b2)
    XCTAssert(j32.isBidirectional)
    XCTAssertFalse(j32.isRandomAccess)
    j32.checkBidirectionalCollectionSemantics(expectedValues: joined)

    let j33 = a3.joined(to: b3)
    XCTAssert(j33.isRandomAccess)
    j33.checkRandomAccessCollectionSemantics(expectedValues: joined)
  }

  func testJoinSetToArray() {
    let s = Set(["1", "2", "3"])
    let c = s.joined(to: ["10", "11", "12"])
    c.checkCollectionSemantics(expectedValues: Array(s) + ["10", "11", "12"])
  }

  func testJoinRanges() {
    let c = (0..<3).joined(to: 3...6)
    c.checkRandomAccessCollectionSemantics(expectedValues: 0...6)
  }

  func testJoinEmptyPrefix() {
    let c = (0..<0).joined(to: [1, 2, 3])
    c.checkRandomAccessCollectionSemantics(expectedValues: 1...3)
  }

  func testJoinEmptySuffix() {
    let c = (1...3).joined(to: 1000..<1000)
    c.checkRandomAccessCollectionSemantics(expectedValues: [1, 2, 3])
  }

  static var allTests = [
    ("testInit", testInit),
    ("testConditionalConformances", testConditionalConformances),
    ("testJoinSetToArray", testJoinSetToArray),
    ("testJoinRanges", testJoinRanges),
    ("testJoinEmptyPrefix", testJoinEmptyPrefix),
    ("testJoinEmptySuffix", testJoinEmptySuffix),
  ]
}
