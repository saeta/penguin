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



/// A fixed-size, contiguous collection allowing additions and removals at either end (space
/// permitting).
///
/// Beware: unbalanced pushes/pops to either the front or the back will result in the effective
/// working size to be diminished. If you would like this to be managed for you automatically,
/// please use a `Deque`.
///
/// - SeeAlso: `Deque`
public struct DoubleEndedBuffer<T> {
	private var buff: ManagedBuffer<DoubleEndedHeader, T>

	/// Allocate with a given capacity and insertion `initialPolicy`.
	///
	/// - Parameter capacity: The capacity of the buffer.
	/// - Parameter initialPolicy: The policy for where initial values should be inserted into the
	///   buffer. Note: asymmetric pushes/pops to front/back will cause the portion of the consumed
	///   buffer to drift. If you need management to occur automatically, please use a Deque.
	public init(capacity: Int, with initialPolicy: DoubleEndedAllocationPolicy) {
		assert(capacity > 3)
		buff = DoubleEndedBufferImpl<T>.create(minimumCapacity: capacity) { buff in
			switch initialPolicy {
			case .beginning:
				return DoubleEndedHeader(start: 0, end: 0)
			case .middle:
				let approxMiddle = buff.capacity / 2
				return DoubleEndedHeader(start: approxMiddle, end: approxMiddle)
			case .end:
				return DoubleEndedHeader(start: buff.capacity, end: buff.capacity)
			}
		}
	}

	/// True if no elements are contained within the data structure, false otherwise.
	public var isEmpty: Bool {
		buff.header.start == buff.header.end
	}

	/// Returns the number of elements contained within `self`.
	public var count: Int {
		buff.header.end - buff.header.start
	}

	/// Returns the capacity of `self`.
	public var capacity: Int {
		buff.capacity
	}

	/// True iff there is available space at the beginning of the buffer.
	public var canPushFront: Bool {
		buff.header.start != 0
	}

	/// True iff there is available space at the end of the buffer.
	public var canPushBack: Bool {
		buff.header.end < buff.capacity
	}

	/// Add elem to the back of the buffer.
	///
	/// - Precondition: `canPushBack`.
	public mutating func pushBack(_ elem: T) {
		precondition(canPushBack, "Cannot pushBack!")
		ensureBuffIsUniquelyReferenced()
		buff.withUnsafeMutablePointerToElements { buffP in
			let offset = buffP.advanced(by: buff.header.end)
			offset.initialize(to: elem)
		}
		buff.header.end += 1
	}

	/// Removes and returns the element at the back, reducing `self`'s count by one.
	///
	/// - Precondition: !isEmpty
	public mutating func popBack() -> T {
		precondition(!isEmpty, "Cannot popBack from empty buffer!")
		ensureBuffIsUniquelyReferenced()
		buff.header.end -= 1
		return buff.withUnsafeMutablePointerToElements { buffP in
			buffP.advanced(by: buff.header.end).move()
		}
	}

	/// Adds elem to the front of the buffer.
	///
	/// - Precondition: `canPushFront`.
	public mutating func pushFront(_ elem: T) {
		precondition(canPushFront, "Cannot pushFront!")
		ensureBuffIsUniquelyReferenced()
		buff.header.start -= 1
		buff.withUnsafeMutablePointerToElements { buffP in
			let offset = buffP.advanced(by: buff.header.start)
			offset.initialize(to: elem)
		}
	}

	/// Removes and returns the element at the front, reducing `self`'s count by one.
	public mutating func popFront() -> T {
		precondition(!isEmpty, "Cannot popFront from empty buffer!")
		ensureBuffIsUniquelyReferenced()
		buff.header.start += 1
		return buff.withUnsafeMutablePointerToElements { buffP in
			buffP.advanced(by: buff.header.start - 1).move()
		}
	}

	/// Makes a copy of the backing buffer if it's not uniquely referenced; does nothing otherwise.
	private mutating func ensureBuffIsUniquelyReferenced() {
		if !isKnownUniquelyReferenced(&buff) {
			// make a copy of the backing store.
			let copy = DoubleEndedBufferImpl<T>.create(minimumCapacity: buff.capacity) { copy in
				return buff.header
			}
			copy.withUnsafeMutablePointerToElements { copyP in
				buff.withUnsafeMutablePointerToElements { buffP in
					let copyOffset = copyP.advanced(by: buff.header.start)
					let buffOffset = UnsafePointer(buffP).advanced(by: buff.header.start)
					copyOffset.initialize(from: buffOffset, count: buff.header.end - buff.header.start)
				}
			}
			self.buff = copy
		}
	}

	/// Explicitly reallocate the backing buffer.
	public mutating func reallocate(
		newCapacity: Int,
		with initialPolicy: DoubleEndedAllocationPolicy
	) {
		assert(newCapacity >= count)
		let newHeader: DoubleEndedHeader
		switch initialPolicy {
		case .beginning:
			newHeader = DoubleEndedHeader(start: 0, end: count)
		case .middle:
			let newStart = (newCapacity - count) / 2
			newHeader = DoubleEndedHeader(start: newStart, end: newStart + count)
		case .end:
			newHeader = DoubleEndedHeader(start: newCapacity - count, end: newCapacity)
		}
		let copy = DoubleEndedBufferImpl<T>.create(minimumCapacity: newCapacity) { copy in
			newHeader
		}
		if !isKnownUniquelyReferenced(&buff) {
			// Don't touch existing one; must make a copy of buffer contents.
			copy.withUnsafeMutablePointerToElements { copyP in
				buff.withUnsafeMutablePointerToElements { buffP in
					let copyOffset = copyP.advanced(by: copy.header.start)
					let buffOffset = UnsafePointer(buffP).advanced(by: buff.header.start)
					copyOffset.initialize(from: buffOffset, count: count)
				}
			}
		} else {
			// Move values out of existing buffer into new buffer.
			copy.withUnsafeMutablePointerToElements { copyP in
				buff.withUnsafeMutablePointerToElements { buffP in
					let copyOffset = copyP.advanced(by: copy.header.start)
					let buffOffset = buffP.advanced(by: buff.header.start)
					copyOffset.moveInitialize(from: buffOffset, count: count)
				}
			}
			buff.header.end = buff.header.start  // don't deinitialize uninitialized memory.
		}
		self.buff = copy
	}
}

extension DoubleEndedBuffer: Collection {
	public var startIndex: Int { buff.header.start }
	public var endIndex: Int { buff.header.end }
	public func index(after: Int) -> Int { after + 1 }
	
	public subscript(index: Int) -> T {
		get {
			assert(index >= buff.header.start)
			assert(index < buff.header.end)
			return buff.withUnsafeMutablePointerToElements { $0[index] }
		}
		_modify {
			assert(index >= buff.header.start)
			assert(index < buff.header.end)
			ensureBuffIsUniquelyReferenced()
			var tmp = buff.withUnsafeMutablePointerToElements { $0.advanced(by: index).move() }
			// Ensure we re-initialize the memory!
			defer {
				buff.withUnsafeMutablePointerToElements {
					$0.advanced(by: index).initialize(to: tmp)
				}
			}
			yield &tmp
		}
	}
}

public enum DoubleEndedAllocationPolicy {
	/// Begin allocating elements at the beginning of the buffer.
	case beginning
	/// Begin allocating in the middle of the buffer.
	case middle
	/// Begin allocating at the end of the buffer.
	case end
}

private struct DoubleEndedHeader {
	/// The first index with valid data.
	var start: Int
	/// The index one after the last index with valid data.
	var end: Int
}

private class DoubleEndedBufferImpl<T>: ManagedBuffer<DoubleEndedHeader, T> {
	deinit {
		if header.end != header.start {
			withUnsafeMutablePointerToElements { elems in
				let base = elems.advanced(by: header.start)
				base.deinitialize(count: header.end - header.start)
			}
		}
	}
}
