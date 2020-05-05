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

final class NonblockingConditionTests: XCTestCase {
  typealias Cond = NonblockingCondition<PosixConcurrencyPlatform>

  func testSimple() {
    // Spawn 3 threads to wait on a `Cond`. Wait until they've started, and then notify one, and
    // then notify all.

    let plt = PosixConcurrencyPlatform()
    var waiterCount = 0
    let coordCondVar = PosixConcurrencyPlatform.ConditionMutex()

    let nbc = Cond(threadCount: 3)
    var threads = [PosixConcurrencyPlatform.Thread]()

    for i in 0..<3 {
      let thread = plt.makeThread(name: "test thread \(i)") {
        coordCondVar.lock()
        waiterCount += 1
        nbc.preWait()
        coordCondVar.unlock()
        nbc.commitWait(i)
        // Should be woken up.
      }
      threads.append(thread)
    }
    coordCondVar.lock()
    coordCondVar.await { waiterCount == 3 }
    nbc.notify()
    nbc.notify(all: true)
    for i in 0..<3 {
      threads[i].join()
    }
  }

  func testRepeatedNotification() {
    let nbc = Cond(threadCount: 3)
    for _ in 0..<1000 {
      nbc.notify()
    }
  }

  func testNotifyWhileCommitting() {
    let nbc = Cond(threadCount: 3)
    nbc.preWait() // Thread 1
    nbc.notify()  // Thread 2
    nbc.commitWait(1)  // Should not go to sleep, but instead consume the previous notify.
  }

  func testNotifyAllWhileMultipleCommitting() {
    let nbc = Cond(threadCount: 5)
    nbc.preWait()  // Thread 1
    nbc.preWait()  // Thread 2
    nbc.preWait()  // Thread 3
    nbc.notify(all: true) // Thread 4
    nbc.preWait()  // Thread 5
    nbc.commitWait(1)
    nbc.cancelWait()  // Thread 5
    nbc.commitWait(2)
    nbc.commitWait(3)
  }

  static var allTests = [
    ("testSimple", testSimple),
    ("testRepeatedNotification", testRepeatedNotification),
    ("testNotifyWhileCommitting", testNotifyWhileCommitting),
    ("testNotifyAllWhileMultipleCommitting", testNotifyAllWhileMultipleCommitting),
  ]
}
