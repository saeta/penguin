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
import PenguinStructures

final class DoubleEndedBufferTests: XCTestCase {

	func testSimple() {
		var b = DoubleEndedBuffer<Int>(capacity: 10, with: .beginning)
		XCTAssert(b.isEmpty)
		XCTAssert(b.canPushBack)
		XCTAssertFalse(b.canPushFront)
		for i in 0..<10 {
			XCTAssert(b.canPushBack)
			XCTAssertEqual(i, b.count)
			b.pushBack(i)
			XCTAssertFalse(b.isEmpty)
		}
		XCTAssertFalse(b.canPushBack)
		for i in 0..<10 {
			XCTAssertFalse(b.isEmpty)
			XCTAssertEqual(i, b.popFront())
		}
		XCTAssert(b.isEmpty)
		XCTAssertFalse(b.canPushBack)
		for i in 0..<10 {
			XCTAssert(b.canPushFront)
			b.pushFront(i)
		}
		XCTAssertFalse(b.canPushFront)
	}

	func testInitializations() {
		let beginning = DoubleEndedBuffer<Int>(capacity: 10, with: .beginning)
		XCTAssert(beginning.canPushBack)
		XCTAssertFalse(beginning.canPushFront)

		let middle = DoubleEndedBuffer<Int>(capacity: 10, with: .middle)
		XCTAssert(middle.canPushFront)
		XCTAssert(middle.canPushBack)

		let end = DoubleEndedBuffer<Int>(capacity: 10, with: .end)
		XCTAssertFalse(end.canPushBack)
		XCTAssert(end.canPushFront)
	}

	func testCollection() {
		var b = DoubleEndedBuffer<Int>(capacity: 10, with: .middle)
		b.pushFront(2)
		b.pushFront(1)
		b.pushFront(0)

		XCTAssertEqual([0, 1, 2], Array(b))

		b.pushBack(3)
		b.pushBack(4)
		XCTAssertEqual([0, 1, 2, 3, 4], Array(b))

		XCTAssertEqual(3, b[5])
		b[5] = 10
		XCTAssertEqual([0, 1, 2, 10, 4], Array(b))		
	}

	func testMemoryLeaks() {
		XCTAssert(MemoryChecker.allDeleted)

		do {
			var b = DoubleEndedBuffer<MemoryChecker>(capacity: 10, with: .end)
			b.pushFront(MemoryChecker())
			XCTAssertFalse(MemoryChecker.allDeleted)
		}
		XCTAssert(MemoryChecker.allDeleted)

		do {
			let startCount = MemoryChecker.idCounter
			var b = DoubleEndedBuffer<MemoryChecker>(capacity: 10, with: .beginning)
			b.pushBack(MemoryChecker())
			b[0] = MemoryChecker()
			XCTAssertEqual(2, MemoryChecker.idCounter - startCount)
			XCTAssertEqual(1, MemoryChecker.idCounter - MemoryChecker.deletedCount)
			_ = b.popFront()
			XCTAssert(MemoryChecker.allDeleted)
		}
		XCTAssert(MemoryChecker.allDeleted)
	}

	func testValueSemantics() {
		var b = DoubleEndedBuffer<Int>(capacity: 10, with: .beginning)
		let t0 = b
		for i in 0..<10 {
			XCTAssert(t0.isEmpty)
			b.pushBack(i)
		}
		XCTAssertEqual(Array(0..<10), Array(b))

		let t1 = b
		for _ in 0..<10 {
			_ = b.popFront()
		}
		XCTAssertEqual(Array(0..<10), Array(t1))
		XCTAssert(b.isEmpty)
	}

	func testReallocation() {
		var b = DoubleEndedBuffer<Int>(capacity: 8, with: .beginning)
		for i in 0..<8 {
			b.pushBack(i)
		}
		let t0 = b
		b.reallocate(newCapacity: 16, with: .middle)
		XCTAssert(b.canPushFront)
		XCTAssert(b.canPushBack)
		for i in 8..<12 {
			b.pushFront(i)
		}
		for i in 12..<16 {
			b.pushBack(i)
		}
		XCTAssertEqual(Array(0..<8), Array(t0))
		XCTAssertEqual(Array(8..<12).reversed() + Array(0..<8) + Array(12..<16), Array(b))
	}

	static var allTests = [
		("testSimple", testSimple),
		("testInitializations", testInitializations),
		("testCollection", testCollection),
		("testMemoryLeaks", testMemoryLeaks),
		("testValueSemantics", testValueSemantics),
		("testReallocation", testReallocation),
	]
}

private class MemoryChecker {
	var id: Int
	init() {
		id = Self.idCounter
		Self.idCounter += 1
	}

	deinit {
		Self.deletedCount += 1
	}

	static var idCounter: Int = 0
	static var deletedCount: Int = 0
	static var allDeleted: Bool { idCounter == deletedCount }
}
