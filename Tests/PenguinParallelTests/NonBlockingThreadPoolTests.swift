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
    print("here.")
    let pool = Pool(name: "testThreadIndex", threadCount: threadCount)
    print("here2.")

    let condition = NSCondition()
    var threadsSeenCount = 0  // guarded by condition.
    var seenWorkItems = Set<Int>()

    for work in 0..<threadCount {
      print("dispatching \(work)")
      pool.dispatch {
        condition.lock()
        print("running \(work), threadsSeenCount: \(threadsSeenCount)")
        threadsSeenCount += 1
        seenWorkItems.insert(work)
        if threadsSeenCount == threadCount {
          condition.signal()
        }
        condition.unlock()
      }
    }

    print("about to wait on condition...")
    condition.lock()
    while threadsSeenCount != threadCount {
      print("seen count: \(threadsSeenCount)")
      condition.wait()
    }
    print("Almost done!")
    condition.unlock()
  }

  static var allTests = [
    ("testThreadIndexDispatching", testThreadIndexDispatching),
  ]
}