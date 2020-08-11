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

final class TypeIDTests: XCTestCase {
  func test_init() {
    XCTAssert(TypeID(Int.self).value == Int.self)
    XCTAssert(TypeID(String.self).value == String.self)
  }

  func test_hashable() {
    TypeID(Int.self).checkHashableSemantics()
  }

  func test_comparable() {
    let (min, mid, max) = TypeID.sort3(TypeID(Int.self), TypeID(UInt.self), TypeID(Int8.self))
    min.checkComparableSemantics(greater: mid, greaterStill: max)
  }
  
  static let allTests = [
    ("test_init", test_init),
    ("test_hashable", test_hashable),
    ("test_comparaqble", test_comparable),
  ]
}
