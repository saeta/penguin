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

/// A hierarchical collection of `Element`s, partially ordered so that finding the minimum element
/// can be done in constant time.
public struct Heap<Element> {

	// TODO: convert to B-Heap instead of binary-heap.
	/// The buffer containing the elements of `self`.
	///
	/// - Invariant: elements are ordered in a full, binary tree implicitly within the array, such
	///   that the parent is of lower priority than its two children.
	private var buffer = [(Element, Int)]()

	/// Initialize an empty Heap.
	public init() {}

	/// The number of elements 
	public var count: Int {
		buffer.count
	}

	/// True iff there are no elements within `self`.
	public var isEmpty: Bool {
		count == 0
	}

	/// Adds `elem` with the specified `priority` to `self`.
	public mutating func add(_ elem: Element, with priority: Int) {
		buffer.append((elem, priority))
		bubbleUp(startingAt: buffer.count - 1)
	}

	/// Removes and returns the element with the smallest `priority` value from `self`.
	public mutating func popFront() -> Element? {
		if let tmp = popFrontWithPriority() {
			return tmp.0
		}
		return nil
	}

	/// Removes and returns the element with the smallest `priority` from `self`.
	public mutating func popFrontWithPriority() -> (element: Element, priority: Int)? {
		guard !isEmpty else { return nil }
		// Swap first and last elements
		buffer.swapAt(0, buffer.count - 1)
		let tmp = buffer.popLast()
		sinkDown(startingAt: 0)
		return tmp
	}

	/// Performs a series of swap's to restore the invariants of the data structure.
	private mutating func bubbleUp(startingAt index: Int) {
		var i = index
		while true {
			let p = parent(of: i)
			if buffer[i].1 < buffer[p].1 {
				buffer.swapAt(p, i)
				i = p
			} else {
				return  // We're done!
			}
		}
	}

	/// Performs a series of swap's to restore the invariants of the data structure.
	private mutating func sinkDown(startingAt index: Int) {
		var i = index
		while true {
			var minIndex = i
			if let leftIndex = leftChild(of: i), buffer[leftIndex].1 < buffer[minIndex].1 {
				minIndex = leftIndex
			}
			if let rightIndex = rightChild(of: i), buffer[rightIndex].1 < buffer[minIndex].1 {
				minIndex = rightIndex
			}
			if minIndex == i { return }  // Done!
			buffer.swapAt(i, minIndex)
			i = minIndex  // Keep going to see if more work is necessary.
		}
	}

	/// Computes the index of the parent of `index`.
	private func parent(of index: Int) -> Int {
		(index - 1) / 2
	}

	/// Computes the left child of `index`, if it exists.
	private func leftChild(of index: Int) -> Int? {
		let childIndex = 2 * index + 1
		if childIndex < buffer.count { return childIndex }
		return nil
	}

	/// Computes the right child of `index`, if it exists.
	private func rightChild(of index: Int) -> Int? {
		let childIndex = 2 * index + 2
		if childIndex < buffer.count { return childIndex }
		return nil
	}
}

extension Heap: CustomStringConvertible {
	public var description: String {
		var str = ""
		for (i, elem) in buffer.enumerated() {
			str.append(" - \(i): p\(elem.1) (\(elem.0))")
			if i != 0 {
				let p = parent(of: i)
				str.append(" [parent: \(p) @ p\(buffer[p].1)]")
			}
			str.append("\n")
		}
		return str
	}
}

/// A hierarchical collection of elements, partially ordered such that finding the lowest priority
/// element can be done in constant time; also supports updating the priority of an element.
///
/// - Invariant: Only a single copy of an element can be contained within at a single time.
public struct UpdatableUniqueHeap<Element: Hashable> {

	// TODO: convert to B-Heap instead of binary-heap.
	/// The buffer containing the elements of `self`.
	///
	/// - Invariant: elements are ordered in a full, binary tree implicitly within the array, such
	///   that the parent is of lower priority than its two children.
	private var buffer = [(Element, Int)]()
	/// A mapping from element to its position in `buffer`.
	private var positions = [Element: Int]()

	/// Initialize an empty Heap.
	public init() {}

	/// The number of elements 
	public var count: Int {
		buffer.count
	}

	/// True iff there are no elements within `self`.
	public var isEmpty: Bool {
		count == 0
	}

	/// Adds `elem` with the specified `priority` to `self`.
	///
	/// - Precondition: `elem` is not within `self`.
	public mutating func add(_ elem: Element, with priority: Int) {
		assert(positions[elem] == nil, "\(elem) already in \(self).")
		buffer.append((elem, priority))
		bubbleUp(startingAt: buffer.count - 1)  // bubbleUp will set `positions[]`.
	}

	/// Removes and returns the element with the smallest `priority` value from `self`.
	public mutating func popFront() -> Element? {
		if let tmp = popFrontWithPriority() {
			return tmp.0
		}
		return nil
	}

	/// Removes and returns the element with the smallest `priority` from `self`.
	public mutating func popFrontWithPriority() -> (element: Element, priority: Int)? {
		guard !isEmpty else { return nil }
		// Swap first and last elements
		buffer.swapAt(0, buffer.count - 1)
		let tmp = buffer.popLast()
		// Note: positions[buffer[0].0] will be updated inside `sinkDown`.
		positions[tmp!.0] = nil
		sinkDown(startingAt: 0)
		return tmp
	}

	/// Updates the priority of `elem` to `newPriority`.
	///
	/// - Precondition: `elem` is contained within `self`.
	/// - Complexity: O(log n)
	public mutating func update(_ elem: Element, withNewPriority newPriority: Int) {
		guard let originalPosition = positions[elem] else {
			preconditionFailure("\(elem) was not found within `self`.")
		}
		let originalPriority = buffer[originalPosition].1
		buffer[originalPosition].1 = newPriority
		if originalPriority < newPriority {
			sinkDown(startingAt: originalPosition)
		} else {
			bubbleUp(startingAt: originalPosition)
		}
	}

	/// Performs a series of swap's to restore the invariants of the data structure.
	private mutating func bubbleUp(startingAt index: Int) {
		var i = index
		while true {
			let p = parent(of: i)
			if buffer[i].1 < buffer[p].1 {
				buffer.swapAt(p, i)
				positions[buffer[i].0] = i
				i = p
			} else {
				positions[buffer[i].0] = i  // Ensure we've updated the positions map.
				return  // We're done!
			}
		}
	}

	/// Performs a series of swap's to restore the invariants of the data structure.
	private mutating func sinkDown(startingAt index: Int) {
		if buffer.isEmpty { return }
		var i = index
		while true {
			var minIndex = i
			if let leftIndex = leftChild(of: i), buffer[leftIndex].1 < buffer[minIndex].1 {
				minIndex = leftIndex
			}
			if let rightIndex = rightChild(of: i), buffer[rightIndex].1 < buffer[minIndex].1 {
				minIndex = rightIndex
			}
			if minIndex == i {
				positions[buffer[i].0] = i
				return  // Done!
			}
			buffer.swapAt(i, minIndex)
			positions[buffer[i].0] = i
			i = minIndex  // Keep going to see if more work is necessary.
		}
	}

	/// Computes the index of the parent of `index`.
	private func parent(of index: Int) -> Int {
		(index - 1) / 2
	}

	/// Computes the left child of `index`, if it exists.
	private func leftChild(of index: Int) -> Int? {
		let childIndex = 2 * index + 1
		if childIndex < buffer.count { return childIndex }
		return nil
	}

	/// Computes the right child of `index`, if it exists.
	private func rightChild(of index: Int) -> Int? {
		let childIndex = 2 * index + 2
		if childIndex < buffer.count { return childIndex }
		return nil
	}
}
