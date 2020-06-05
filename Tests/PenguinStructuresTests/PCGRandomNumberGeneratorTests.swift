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

final class PCGRandomNumberGeneratorTests: XCTestCase {
  /// Using the same state and seed as the corresponding test in the reference
  /// implementation.
  ///
  /// - SeeAlso: https://github.com/imneme/pcg-c/blob/03a84f9db5782a3f5a66185836f3db73c832251a/test-low/expected/check-setseq-64-xsh-rs-32.out
  func testUnderlyingPCG() {
    var rng = PCG_XSH_RS_32_Generator(state: 42, stream: 54)

    XCTAssertEqual(rng.next(), 0x5c1b65c0)
    XCTAssertEqual(rng.next(), 0x8ffceb31)
    XCTAssertEqual(rng.next(), 0xcccad075)
    XCTAssertEqual(rng.next(), 0xb83cdfc6)
    XCTAssertEqual(rng.next(), 0x5dfce9ca)
    XCTAssertEqual(rng.next(), 0xc0d524ec)

    rng = PCG_XSH_RS_32_Generator(state: 42, stream: 54)

    XCTAssertEqual(rng.next(), 0x5c1b65c0)
    XCTAssertEqual(rng.next(), 0x8ffceb31)
    XCTAssertEqual(rng.next(), 0xcccad075)
    XCTAssertEqual(rng.next(), 0xb83cdfc6)
    XCTAssertEqual(rng.next(), 0x5dfce9ca)
    XCTAssertEqual(rng.next(), 0xc0d524ec)
  }

  func testPCG() {
    var rng = PCGRandomNumberGenerator(seed: 42, seq: 54)

    XCTAssertEqual(rng.next(), 0x5c1b65c01468dd76)
  }

  func testDerivedMethods() {
    var rng = PCGRandomNumberGenerator(seed: 42, seq: 54)

    XCTAssertEqual(rng.next(upperBound: 1), 0 as UInt16)
  }

  static var allTests = [
    ("testUnderlyingPCG", testUnderlyingPCG),
    ("testPCG", testPCG),
    ("testDerivedMethods", testDerivedMethods),
  ]
}
