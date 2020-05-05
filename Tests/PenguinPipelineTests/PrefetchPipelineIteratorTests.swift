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

import PenguinPipeline
import XCTest

final class PrefetchPipelineIteratorTests: XCTestCase {

  func testSimplePrefetch() {
    XCTAssert(PipelineIterator._allThreadsStopped())
    // Do everything in a do-block to ensure the iterator is cleaned up before
    // checking to ensure all threads have been stopped.
    do {
      var semaphores = [DispatchSemaphore]()
      semaphores.reserveCapacity(6)
      for _ in 0..<6 {
        semaphores.append(DispatchSemaphore(value: 0))
      }

      var i = 0
      let tmp = PipelineIterator.fromFunction(Int.self) {
        let oldI = i
        defer {
          // Use a defer block to signal at the last possible moment
          // to ensure more reliable execution.
          semaphores[oldI].signal()
        }
        i += 1
        if i >= 6 { return nil }
        return 10 + i
      }
      var itr = tmp.prefetch(3)
      // Wait & verify prefetching did occur!
      semaphores[0].wait()
      semaphores[1].wait()
      semaphores[2].wait()
      Thread.sleep(forTimeInterval: 0.01)  // Sleep to ensure background thread has run.
      XCTAssertEqual(3, i)
      XCTAssertEqual(11, try! itr.next())
      semaphores[3].wait()
      XCTAssertEqual(4, i)
      XCTAssertEqual(12, try! itr.next())
      XCTAssertEqual(13, try! itr.next())
      XCTAssertEqual(14, try! itr.next())
      XCTAssertEqual(15, try! itr.next())
      XCTAssertEqual(nil, try! itr.next())
    }
    XCTAssert(PipelineIterator._allThreadsStopped())
  }

  static var allTests = [
    ("testSimplePrefetch", testSimplePrefetch)
  ]
}
