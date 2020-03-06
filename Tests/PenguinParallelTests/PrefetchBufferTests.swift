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
@testable import PenguinParallel

final class PrefetchBufferTests: XCTestCase {

    func testSynchronousExecution() {
        var buffer = PrefetchBuffer<Int>(PrefetchBufferConfiguration())
        XCTAssert(buffer.push(.success(1)))
        assertSuccess(1, buffer.pop())
        XCTAssertFalse(buffer.isEmpty)
        XCTAssert(buffer.push(.success(2)))
        assertSuccess(2, buffer.pop())
        XCTAssertFalse(buffer.isEmpty)
        buffer.close()
        XCTAssert(buffer.isEmpty)
    }

    func testClosingWhileFull() {
        var buffer = PrefetchBuffer<Int>(PrefetchBufferConfiguration(initialCapacity: 4))
        XCTAssert(buffer.push(.success(1)))
        XCTAssert(buffer.push(.success(2)))
        XCTAssert(buffer.push(.success(3)))
        XCTAssertFalse(buffer.isEmpty)
        buffer.close()
        XCTAssertFalse(buffer.isEmpty)
        assertSuccess(1, buffer.pop())
        XCTAssertFalse(buffer.isEmpty)
        assertSuccess(2, buffer.pop())
        XCTAssertFalse(buffer.isEmpty)
        assertSuccess(3, buffer.pop())
        XCTAssert(buffer.isEmpty)
    }

    func testCloseWhilePopping() {
        if #available(OSX 10.12, *) {
            let s1 = DispatchSemaphore(value: 0)
            let s2 = DispatchSemaphore(value: 0)
            var hasCompleted = false
            var buffer = PrefetchBuffer<Int>(PrefetchBufferConfiguration(initialCapacity: 3))
             Thread.detachNewThread {
                s1.signal()  // Popping commenced!
                let res = buffer.pop()  // This call should block.
                XCTAssert(res == nil)
                hasCompleted = true
                s2.signal()
            }
            s1.wait()
            Thread.sleep(forTimeInterval: 0.0001)  // Ensure the other thread wins the race.
            XCTAssertFalse(hasCompleted)
            buffer.close()  // Close the buffer
            s2.wait()
            XCTAssert(hasCompleted)
        }
    }

    func testCloseWhilePushing() {
        if #available(OSX 10.12, *) {
            let s1 = DispatchSemaphore(value: 0)
            let s2 = DispatchSemaphore(value: 0)
            var buffer = PrefetchBuffer<Int>(PrefetchBufferConfiguration(initialCapacity: 3))
            var hasCompleted = false
            XCTAssert(buffer.push(.success(1)))
            XCTAssert(buffer.push(.success(1)))
            Thread.detachNewThread {
                s1.signal()  // Popping commenced!
                XCTAssertFalse(buffer.push(.success(1)))  // This call should block.
                hasCompleted = true
                s2.signal()
            }
            s1.wait()
            Thread.sleep(forTimeInterval: 0.0001)  // Ensure the other thread wins the race.
            XCTAssertFalse(hasCompleted)
            buffer.close()  // Close the buffer
            s2.wait()
            XCTAssert(hasCompleted)
            XCTAssertFalse(buffer.isEmpty)
            assertSuccess(1, buffer.pop())
            assertSuccess(1, buffer.pop())
            XCTAssertNil(buffer.pop())
        }
    }

    // TODO(saeta): test where consumer wants to stop consuming while producer blocked trying to push.

    static var allTests = [
        ("testSynchronousExecution", testSynchronousExecution),
        ("testClosingWhileFull", testClosingWhileFull),
        ("testCloseWhilePopping", testCloseWhilePopping),
        ("testCloseWhilePushing", testCloseWhilePushing),
    ]
}

fileprivate func assertSuccess<T: Equatable>(_ expected: T, _ other: Result<T, Error>?, file: StaticString = #file, line: Int = #line) {
    guard let other = other else {
        XCTFail("Got nil when expected \(expected).")
        return
    }
    switch other {
    case let .success(other):
        XCTAssertEqual(expected, other)
    default:
        XCTFail("Failure (\(file):\(line)): \(expected) != \(other)")
    }
}
