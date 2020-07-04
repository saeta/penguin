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
  
  func testComparable() {
    Either<Int, Int>.checkComparableSemantics(.a(1), .a(2), .a(1000), .b(-3), .b(0), .b(5))

    Either<String, Int>.checkComparableSemantics(
      Either(""), Either("abc"), Either("xyz"), Either(-4), Either(0), Either(10))
  }

  static var allTests = [
    ("testComparable", testComparable),
  ]
}
