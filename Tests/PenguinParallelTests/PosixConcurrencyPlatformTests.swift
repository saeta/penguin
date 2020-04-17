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

final class PosixConcurrencyPlatformTests: XCTestCase {
  func testThreadCreationAndJoining() {
    let platform = PosixConcurrencyPlatform()
    let emptyThread = platform.makeThread(name: "test thread") { /* empty */  }
    emptyThread.join()
  }

  func testLocksAndSynchronization() {
    let platform = PosixConcurrencyPlatform()

    let condVar = PosixConcurrencyPlatform.ConditionVariable()
    let lock = PosixConcurrencyPlatform.Mutex()

    // Initialize to 0; main thread increments to 1, test thread increases to 2, main thread
    // increases to 3, and then we're done.
    var stateMachine = 0

    let testThread = platform.makeThread(name: "test thread") {
      lock.withLock {
        while stateMachine == 0 {
          condVar.wait(lock)
        }
        XCTAssertEqual(1, stateMachine)
        stateMachine = 2
        condVar.signal()
      }
      lock.withLock {
        while stateMachine < 3 {
          condVar.wait(lock)
        }
        XCTAssertEqual(3, stateMachine)
      }
    }

    lock.withLock {
      XCTAssertEqual(0, stateMachine)
      stateMachine = 1
      condVar.signal()
    }

    lock.withLock {
      while stateMachine < 2 {
        condVar.wait(lock)
      }
      XCTAssertEqual(2, stateMachine)
      stateMachine = 3
      condVar.signal()
    }
    testThread.join()
  }

  func testConditionMutexPingPong() {
    let platform = PosixConcurrencyPlatform()
    let condMutex = PosixConcurrencyPlatform.ConditionMutex()
    let threadCount = 5
    // incremented by each thread in turn.
    var state = 0
    let threads = (0..<threadCount).map { threadIndex in
      platform.makeThread(name: "test thread \(threadIndex)") {
        for i in 0..<100 {
          condMutex.lockWhen({ state % threadCount == threadIndex }) {
            XCTAssertEqual(state, (i * threadCount) + threadIndex)
            state += 1
          }
        }
      }
    }
    for thread in threads { thread.join() }
    XCTAssertEqual(threadCount * 100, state)
  }

  func testThreadLocalVariables() {
    typealias TLS = PosixConcurrencyPlatform.ThreadLocalStorage
    XCTAssertEqual(0, LeakChecker.allocationCount)
    let key = TLS.makeKey(for: LeakChecker.self)

    do {
      let checker = LeakChecker()
      TLS.set(checker, for: key)
      XCTAssertEqual(ObjectIdentifier(checker), ObjectIdentifier(TLS.get(key)!))
      XCTAssertEqual(1, LeakChecker.allocationCount)
    }
    XCTAssertEqual(1, LeakChecker.allocationCount)
    TLS.set(nil, for: key)
    XCTAssertEqual(0, LeakChecker.allocationCount)

    let platform = PosixConcurrencyPlatform()
    var mainThreadObjectIdentifier: ObjectIdentifier
    do {
      let checker = LeakChecker()
      XCTAssertEqual(1, LeakChecker.allocationCount)
      mainThreadObjectIdentifier = ObjectIdentifier(checker)
      TLS.set(checker, for: key)
    }
    XCTAssertEqual(1, LeakChecker.allocationCount)
    let testThread = platform.makeThread(name: "test thread") {
      XCTAssertNil(TLS.get(key))
      XCTAssertEqual(1, LeakChecker.allocationCount)
      TLS.set(LeakChecker(), for: key)
      XCTAssertEqual(2, LeakChecker.allocationCount)
      XCTAssertNotEqual(mainThreadObjectIdentifier, ObjectIdentifier(TLS.get(key)!))
    }
    testThread.join()
    XCTAssertEqual(1, LeakChecker.allocationCount)  // Test thread's TLS should be dealloc'd.
    TLS.set(nil, for: key)
    XCTAssertEqual(0, LeakChecker.allocationCount)  // Clean up the test
  }

  func testThreadLocalSugar() {
    typealias TLS = PosixConcurrencyPlatform.ThreadLocalStorage
    XCTAssertEqual(0, LeakChecker.allocationCount)  // Ensure we're starting from clean.

    let key = TLS.makeKey(for: LeakChecker.self)
    XCTAssertNil(key.localValue)
    key.localValue = LeakChecker()
    XCTAssertEqual(1, LeakChecker.allocationCount)
    XCTAssertNotNil(key.localValue)

    let platform = PosixConcurrencyPlatform()
    let testThread = platform.makeThread(name: "test thread") {
      XCTAssertNil(key.localValue)

      let tmp = TLS.get(key, default: LeakChecker())
      XCTAssertEqual(2, LeakChecker.allocationCount)
      let tmpId = ObjectIdentifier(tmp)

      XCTAssertNotNil(TLS.get(key))
      XCTAssertEqual(tmpId, ObjectIdentifier(TLS.get(key)!))

      let tmp2 = TLS.get(key, default: LeakChecker())
      XCTAssertEqual(tmpId, ObjectIdentifier(tmp2))
      XCTAssertEqual(2, LeakChecker.allocationCount)
    }
    testThread.join()
    XCTAssertEqual(1, LeakChecker.allocationCount)
    key.localValue = nil
    XCTAssertEqual(0, LeakChecker.allocationCount)  // Ensure we clean up correctly.
  }

  static var allTests = [
    ("testThreadCreationAndJoining", testThreadCreationAndJoining),
    ("testLocksAndSynchronization", testLocksAndSynchronization),
    ("testConditionMutexPingPong", testConditionMutexPingPong),
    ("testThreadLocalVariables", testThreadLocalVariables),
    ("testThreadLocalSugar", testThreadLocalSugar),
  ]
}

fileprivate class LeakChecker {
  public init() {
    LeakChecker.allocationCount += 1
  }

  deinit {
    LeakChecker.allocationCount -= 1
  }

  static var allocationCount: Int = 0
}
