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
import PenguinParallelWithFoundation
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

  func testGracefulShutdown() {
    typealias Platform = ThreadCountingPlatform<PosixConcurrencyPlatform>
    typealias Pool = NonBlockingThreadPool<Platform>

    var platformDeleted = false
    do {
      let platform = ThreadCountingPlatform(PosixConcurrencyPlatform()) { platformDeleted = true }
      let threadCount = 17
      do {
        let pool = Pool(
          name: "testGracefulShutdownNoWork", threadCount: threadCount, environment: platform)
        XCTAssertEqual((running: threadCount, created: threadCount), platform.counts)
        // Do no work, then shut down.
        pool.shutDown()
      }
      XCTAssertFalse(platformDeleted)
      XCTAssertEqual((running: 0, created: threadCount), platform.counts)
    }
    XCTAssert(platformDeleted)

    platformDeleted = false  // Reset for next test.
    XCTAssertFalse(platformDeleted)
    do {
      let platform = ThreadCountingPlatform(PosixConcurrencyPlatform()) { platformDeleted = true }
      let threadCount = 19
      do {
        let pool = Pool(
          name: "testGracefulShutdownWorked", threadCount: threadCount, environment: platform)
        XCTAssertEqual((running: threadCount, created: threadCount), platform.counts)
        pool.parallelFor(n: 10000) { (_, _) in }  // Do a bunch of silly work.
        XCTAssertEqual((running: threadCount, created: threadCount), platform.counts)
        pool.shutDown()
        XCTAssertEqual((running: 0, created: threadCount), platform.counts)
      }
      XCTAssertFalse(platformDeleted)
      XCTAssertEqual((running: 0, created: threadCount), platform.counts)
    }
    XCTAssert(platformDeleted)
  }

  static var allTests = [
    ("testThreadIndexDispatching", testThreadIndexDispatching),
    ("testThreadIndexParallelFor", testThreadIndexParallelFor),
    ("testGracefulShutdown", testGracefulShutdown),
  ]
}

// Overload for 2-tuple
#if swift(>=5.3)
fileprivate func XCTAssertEqual(
  _ lhs: (Int, Int), _ rhs: (Int, Int), _ msg: String = "", file: StaticString = #filePath,
  line: UInt = #line
) {
  XCTAssertEqual(
    lhs.0, rhs.0, "items 0 did not agree: \(lhs) vs \(rhs) \(msg)", file: file, line: line)
  XCTAssertEqual(
    lhs.1, rhs.1, "items 1 did not agree: \(lhs) vs \(rhs) \(msg)", file: file, line: line)
}
#else
fileprivate func XCTAssertEqual(
  _ lhs: (Int, Int), _ rhs: (Int, Int), _ msg: String = "", file: StaticString = #file,
  line: UInt = #line
) {
  XCTAssertEqual(
    lhs.0, rhs.0, "items 0 did not agree: \(lhs) vs \(rhs) \(msg)", file: file, line: line)
  XCTAssertEqual(
    lhs.1, rhs.1, "items 1 did not agree: \(lhs) vs \(rhs) \(msg)", file: file, line: line)
}
#endif

/// A platform to count threads and to ensure deallocation.
///
/// `ThreadCountingPlatform` wraps an underlying `ConcurrencyPlatform`, and adds some testing
/// functionality, such as the ability to be informed when the concurrency platform is deleted
/// (useful to ensure there are no memory leaks) as well as guarantee that no threads have been
/// leaked.
public class ThreadCountingPlatform<Underlying: ConcurrencyPlatform>: ConcurrencyPlatform {
  let underlying: Underlying
  let deletionCallback: () -> Void
  let lock = Underlying.Mutex()
  private var runningThreadCount = 0
  private var createdThreadCount = 0

  /// Retrieves the running and created thread counts.
  public var counts: (running: Int, created: Int) {
    lock.lock()
    defer { lock.unlock() }
    return (runningThreadCount, createdThreadCount)
  }

  /// Initializes a thread counting platform wrapping an `underlying` concurrency platform.
  public init(_ underlying: Underlying, _ deletionCallback: @escaping () -> Void) {
    self.underlying = underlying
    self.deletionCallback = deletionCallback
  }

  deinit {
    deletionCallback()
  }

  public typealias Mutex = Underlying.Mutex
  public typealias ConditionMutex = Underlying.ConditionMutex
  public typealias ConditionVariable = Underlying.ConditionVariable
  public typealias Thread = Underlying.Thread
  public typealias BaseThreadLocalStorage = Underlying.BaseThreadLocalStorage

  public func makeThread(name: String, _ fn: @escaping () -> Void) -> Thread {
    lock.lock()
    defer { lock.unlock() }
    createdThreadCount += 1
    runningThreadCount += 1
    return underlying.makeThread(name: name) { [unowned self, fn] () in
      fn()
      self.lock.lock()
      self.runningThreadCount -= 1
      self.lock.unlock()
    }
  }
}
