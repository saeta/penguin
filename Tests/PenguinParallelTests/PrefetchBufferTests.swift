import XCTest
@testable import PenguinParallel

final class PrefetchBufferTests: XCTestCase {

    func testSynchronousExecution() {
        var buffer = PrefetchBuffer<Int>(PrefetchBufferConfiguration())
        buffer.push(.success(1))
        assertSuccess(1, buffer.pop())
        XCTAssertFalse(buffer.isEmpty)
        buffer.push(.success(2))
        assertSuccess(2, buffer.pop())
        XCTAssertFalse(buffer.isEmpty)
        buffer.close()
        XCTAssert(buffer.isEmpty)
    }

    func testClosingWhileFull() {
        var buffer = PrefetchBuffer<Int>(PrefetchBufferConfiguration(initialCapacity: 4))
        buffer.push(.success(1))
        buffer.push(.success(2))
        buffer.push(.success(3))
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
            var buffer = PrefetchBuffer<Int>(PrefetchBufferConfiguration(initialCapacity: 3))
             Thread.detachNewThread {
                s1.signal()  // Popping commenced!
                let res = buffer.pop()  // This call should block.
                XCTAssert(res == nil)
                s2.signal()
            }
            s1.wait()
            Thread.sleep(forTimeInterval: 0.0001)  // Ensure the other thread wins the race.
            buffer.close()  // Close the buffer
            s2.wait()
        }
    }

    // TODO(saeta): test where consumer wants to stop consuming while producer blocked trying to push.

    static var allTests = [
        ("testSynchronousExecution", testSynchronousExecution),
        ("testClosingWhileFull", testClosingWhileFull),
        ("testCloseWhilePopping", testCloseWhilePopping),
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
