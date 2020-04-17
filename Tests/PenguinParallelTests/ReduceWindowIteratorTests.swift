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

final class ReduceWindowIteratorTests: XCTestCase {
  func testReduceWindowSimple() throws {
    do {
      var itr = PipelineIterator.range(to: 10).reduceWindow(windowSize: 3) {
        try $0.collect().sum()
      }
      XCTAssertEqual(3, try! itr.next())  // 0, 1, 2
      XCTAssertEqual(12, try! itr.next())  // 3, 4, 5
      XCTAssertEqual(21, try! itr.next())  // 6, 7, 8
      XCTAssertEqual(19, try! itr.next())  // 9, 10
      XCTAssertNil(try! itr.next())
    }
    XCTAssert(PipelineIterator._allThreadsStopped())
  }

  static var allTests = [
    ("testReduceWindowSimple", testReduceWindowSimple),
  ]
}

extension Array where Element == Int {
  fileprivate func sum() -> Int {
    reduce(0, &+)
  }
}
