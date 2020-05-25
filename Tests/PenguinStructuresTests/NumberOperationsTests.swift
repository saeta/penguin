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

final class NumberOperationsTests: XCTestCase {
  func testCoprimes() {
    XCTAssertEqual([1, 3, 5, 7], 8.smallerPositiveCoprimes)
    XCTAssertEqual([1, 2, 3, 4], 5.smallerPositiveCoprimes)
    XCTAssertEqual([1, 2, 4, 7, 8, 11, 13, 14], 15.smallerPositiveCoprimes)
    XCTAssertEqual([], 1.smallerPositiveCoprimes)

    XCTAssertEqual([1, 3, 5, 7], (-8).smallerPositiveCoprimes)

    XCTAssertEqual([1, 3, 5, 7, 9, 11, 13, 15], Array(8.positiveCoprimes.prefix(8)))
    XCTAssertEqual(Array(1...8), Array(1.positiveCoprimes.prefix(8)))

    XCTAssertEqual([], Array(0.positiveCoprimes.prefix(8)))
  }

  func testGCD() {
  	XCTAssertEqual(3, gcd(0, 3))
  	XCTAssertEqual(3, gcd(3, 0))
  	XCTAssertEqual(4, gcd(-4, 8))

  	XCTAssertEqual(3, gcd(UInt(15), 3))

  	XCTAssertEqual(5, gcd(-5, 0))
  }

  static var allTests = [
    ("testCoprimes", testCoprimes),
    ("testGCD", testGCD),
  ]
}
