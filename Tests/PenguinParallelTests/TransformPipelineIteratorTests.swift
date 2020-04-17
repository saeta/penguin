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

final class TransformPipelineIteratorTests: XCTestCase {

  func testPipelineMapInts() {
    do {
      let arr = [0, 1, 2, 3, 4]
      var itr = arr.makePipelineIterator().map { $0 + 1 }
      XCTAssertEqual(1, try! itr.next())
      XCTAssertEqual(2, try! itr.next())
      XCTAssertEqual(3, try! itr.next())
      XCTAssertEqual(4, try! itr.next())
      XCTAssertEqual(5, try! itr.next())
      XCTAssertEqual(nil, try! itr.next())
    }
    XCTAssert(PipelineIterator._allThreadsStopped())
  }

  func testFilterOdds() {
    do {
      let arr = [0, 1, 2, 3, 4]
      var itr = arr.makePipelineIterator().filter { $0 % 2 == 0 }
      XCTAssertEqual(0, try! itr.next())
      XCTAssertEqual(2, try! itr.next())
      XCTAssertEqual(4, try! itr.next())
      XCTAssertEqual(nil, try! itr.next())
    }
    XCTAssert(PipelineIterator._allThreadsStopped())
  }

  func testCompactMap() {
    do {
      let arr = [0, 1, 2, 3, 4]
      var itr = arr.makePipelineIterator().compactMap { i -> Int? in
        if i % 2 == 0 {
          return i * 2
        } else { return nil }
      }
      XCTAssertEqual(0, try! itr.next())
      XCTAssertEqual(4, try! itr.next())
      XCTAssertEqual(8, try! itr.next())
      XCTAssertEqual(nil, try! itr.next())
    }
    XCTAssert(PipelineIterator._allThreadsStopped())
  }

  // TODO: test the case where the upstream is slow, and consuming is fast.
  // TODO: test the case where one map function is extremely slow, and others are fast (ensure minimal blocking).
  // TODO: test transform function throwing things.
  // TODO: test ... 

  static var allTests = [
    ("testPipelineMapInts", testPipelineMapInts),
    ("testFilterOdds", testFilterOdds),
    ("testCompactMap", testCompactMap),
  ]
}
