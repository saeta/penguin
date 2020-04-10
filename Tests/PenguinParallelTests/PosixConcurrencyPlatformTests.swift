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

import XCTest
import PenguinParallel

final class PosixConcurrencyPlatformTests: XCTestCase {
	func testThreadCreationAndJoining() {
		let platform = PosixConcurrencyPlatform()
		let emptyThread = platform.makeThread(name: "test thread") { /* empty */ }
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

	var allTests = [
		("testThreadCreationAndJoining", testThreadCreationAndJoining),
		("testLocksAndSynchronization", testLocksAndSynchronization),
		("testConditionMutexPingPong", testConditionMutexPingPong),
	]
}
