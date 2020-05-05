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

final class ComputeThreadPoolTests: XCTestCase {
  func testFullyRecursiveParallelFor() {
    /// Tests the default ComputeThreadPool implementation with maximum recursion.
    let inlinePool = InlineComputeThreadPool()
    var arr = Array(repeating: false, count: 103)
    arr.withUnsafeMutableBufferPointer { buff in
      inlinePool.parallelFor(n: buff.count) { (i, _) in
        buff[i] = true
      }
    }
    XCTAssertEqual(Array(repeating: true, count: arr.count), arr)
  }

  static var allTests = [
    ("testFullyRecursiveParallelFor", testFullyRecursiveParallelFor)
  ]
}
