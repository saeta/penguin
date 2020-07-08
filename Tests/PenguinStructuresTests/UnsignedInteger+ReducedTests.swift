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

@testable import PenguinStructures
import XCTest

final class UnsignedInteger_ReducedTests: XCTestCase {
  func testReduction() {
    var results: [UInt8: UInt8] = [:]

    for n in (UInt8.zero ... .max).map({ $0.reduced(into: 3) }) {
      results[n, default: 0] += 1
    }

    XCTAssertEqual(results, [
      0: 86,
      1: 85,
      2: 85
    ])
  }
  static let allTests = [
    ("testReduction", testReduction),
  ]
}
