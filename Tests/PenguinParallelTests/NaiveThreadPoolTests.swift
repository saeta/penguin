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
import Foundation

final class NaiveThreadPoolTests: XCTestCase {

	func testThrowingJoin() throws {
		do {
			try NaiveThreadPool.global.join({ _ in }, { _ in throw TestError() })
			XCTFail("Should have thrown!")
		} catch is TestError {}  // Pass

		do {
			try NaiveThreadPool.global.join({ _ in throw TestError() }, { _ in })
			XCTFail("Should have thrown!")
		} catch is TestError {}  // Pass
	}

	func testThrowingParallelFor() throws {
		do {
			try NaiveThreadPool.global.parallelFor(n: 100) { (i, _) in
				if i == 57 {
					throw TestError()
				}
			}
			XCTFail("Should have thrown!")
		} catch is TestError {
			// Pass!
			return
		}
	}

	func testThreadIndex() {
		let threadCount = NaiveThreadPool.global.parallelism
		// Run `threadCount` tasks, and block on `condition` until all of them have consumed the
		// thread pool resources. Check the thread index on each one to ensure we've seen them all.
		// The main thread waits on `doneCondition` which is notified when `threadsSeenCount`
		// returns to 0.
		let condition = NSCondition()

		// Because the thread pool is intentionally racy (for performance reasons), and assumes work
		// does not block the thread pool, we intentionally do not block indefinitely upon
		// `condition`, and instead try a few times to ensure we appropriately satisfy the test
		// conditions.
		for attempt in 0..<10 {
			var threadsSeenCount = 0  // guarded by condition
			var seenMainThread = false  // guarded by condition
			var seenThreadIds = Set<Int>()  // guarded by condition
			var successfulRun = true  // guarded by condition

			NaiveThreadPool.global.parallelFor(n: threadCount + 1) { (i, _) in
				condition.lock()
				if let threadId = NaiveThreadPool.global.currentThreadIndex {
					threadsSeenCount += 1
					seenThreadIds.insert(threadId)
				} else {
					// Either we've not seen the main thread, or this must be an unsuccessful run.
					XCTAssert(!seenMainThread || !successfulRun,
						"\(attempt): Main thread: \(seenMainThread), successful: \(successfulRun)")
					seenMainThread = true
				}
				if threadsSeenCount == threadCount {
					condition.broadcast()  // Wake up all waiters.
				} else {
					if !condition.wait(until: Date() + 0.05) {  // Wait no more than 50 ms.
						successfulRun = false
					}
				}
				condition.unlock()
			}
			// Finished.
			if !successfulRun { continue }  // try again.
			XCTAssert(seenMainThread)
			XCTAssertEqual(Set(0..<threadCount), seenThreadIds)
			return  // Success!
		}
		XCTFail("Did not have a successful run.")
	}

	static var allTests = [
		("testThrowingParallelFor", testThrowingParallelFor),
		("testThrowingJoin", testThrowingJoin),
		("testThreadIndex", testThreadIndex),
	]
}

fileprivate struct TestError: Error {}