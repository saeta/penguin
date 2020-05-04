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

import PenguinParallel
import XCTest

final class SequencePipelineIteratorTests: XCTestCase {

  func testPipelineIteratorOnArray() {
    let arr = [0, 1, 2, 3, 4]
    var itr = arr.makePipelineIterator()
    XCTAssertEqual(0, try! itr.next())
    XCTAssertEqual(1, try! itr.next())
    XCTAssertEqual(2, try! itr.next())
    XCTAssertEqual(3, try! itr.next())
    XCTAssertEqual(4, try! itr.next())
  }

  static var allTests = [
    ("testPipelineIteratorOnArray", testPipelineIteratorOnArray)
  ]
}
