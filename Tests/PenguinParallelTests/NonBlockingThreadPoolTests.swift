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

import Foundation
import PenguinParallel
import XCTest

final class NonBlockingThreadPoolTests: XCTestCase {
  typealias Pool = NonBlockingThreadPool<PosixConcurrencyPlatform>

  func testThreadIndexDispatching() {
    let threadCount = 7
    let pool = Pool(name: "testThreadIndexDispatching", threadCount: threadCount)

    let condition = NSCondition()
    var threadsSeenCount = 0  // guarded by condition.
    var seenWorkItems = Set<Int>()

    for work in 0..<threadCount {
      pool.dispatch {
        condition.lock()
        threadsSeenCount += 1
        seenWorkItems.insert(work)
        if threadsSeenCount == threadCount {
          condition.signal()
        }
        condition.unlock()
      }
    }

    condition.lock()
    while threadsSeenCount != threadCount {
      condition.wait()
    }
    condition.unlock()
  }

  func testThreadIndexParallelFor() {
    let threadCount = 18
    let pool = Pool(name: "testThreadIndexParallelFor", threadCount: threadCount)

    let condition = NSCondition()
    var seenIndices = Array(repeating: false, count: 10000)  // guarded by condition.

    pool.parallelFor(n: seenIndices.count) { (i, _) in
      condition.lock()
      XCTAssertFalse(seenIndices[i])
      seenIndices[i] = true
      condition.unlock()
    }
    XCTAssert(seenIndices.allSatisfy { $0 })
  }

  static var allTests = [
    ("testThreadIndexDispatching", testThreadIndexDispatching),
    ("testThreadIndexParallelFor", testThreadIndexParallelFor),
  ]
}