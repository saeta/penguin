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
  typealias A<T> = ArrayBuffer<ArrayStorage<T>>
  
  func test_init() {
    let a0 = A<Int>()
    let b0 = AnyArrayBuffer(a0)
    XCTAssertEqual(a0.count, 0)
    XCTAssertEqual(a0.capacity, b0.capacity)
  }

  static var allTests = [
    ("test_init", test_init),
  ]
}
