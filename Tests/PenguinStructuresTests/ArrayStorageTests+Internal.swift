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
@testable import PenguinStructures

// Reusable test implementations

class ArrayStorageTests_Internal: XCTestCase {
  func test_isUsable() {
    let noCapacity = ArrayStorage<Double>()
    XCTAssert(noCapacity.object.isUsable(forElementType: Type<Double>.id))
    XCTAssert(
      noCapacity.object.isUsable(forElementType: Type<Int>.id),
      """
      Storage with zero capacity should be the canonical empty storage, \
      which is valid for any element type.
      """)

    let someCapacity = ArrayStorage<Double>(minimumCapacity: 3)
    XCTAssert(someCapacity.object.isUsable(forElementType: Type<Double>.id))
    XCTAssertFalse(
      someCapacity.object.isUsable(forElementType: Type<Int>.id),
      """
      Storage with non-zero capacity should only be usable for the type \
      of element for which it was created.
      """)
    
    let nonEmpty = ArrayStorage(1...10)
    XCTAssert(nonEmpty.object.isUsable(forElementType: Type<Int>.id))
    XCTAssertFalse(
      nonEmpty.object.isUsable(forElementType: Type<Double>.id),
      """
      Storage with non-zero capacity should only be usable for the type \
      of element for which it was created.
      """)
  }
  
  static var allTests = [
    ("test_isUsable", test_isUsable),
  ]
}
