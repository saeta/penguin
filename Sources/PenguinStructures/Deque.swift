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

// MARK: - Queue

// TODO: how should queue relate to collection?
// TODO: how should this be refined w.r.t. priority queues?
/// A first-in-first-out data structure.
public protocol Queue {
  /// The type of data stored in the queue.
  associatedtype Element

  /// Removes and returns the next element.
  mutating func pop() -> Element?

  /// Adds `element` to `self`.
  mutating func push(_ element: Element)
}

// MARK: - Deques

/// A dynamically-sized double-ended queue that allows pushing and popping at both the front and the
/// back.
public struct Deque<Element> {
  /// A block of data
  private typealias Block = DoubleEndedBuffer<Element>

  /// The elements contained within the data structure.
  ///
  /// Invariant: buff is never empty (it always contains at least one (nested) Block).
  private var buff: DoubleEndedBuffer<Block>

  /// The number of elements contained within `self`.
  public private(set) var count: Int

  /// Creates an empty Deque.
  ///
  /// - Parameter bufferSize: The capacity (in terms of elements) of the initial Deque. If
  ///   unspecified, `Deque` uses a heuristic to pick a value, tuned for performance.
  public init(initialCapacity: Int? = nil) {
    let blockSize: Int
    if let capacity = initialCapacity {
      blockSize = capacity
    } else {
      if MemoryLayout<Element>.stride < 256 {
        // ~4k pages; minus the overheads.
        blockSize = (4096 - MemoryLayout<DoubleEndedHeader>.size - 8) / MemoryLayout<Element>.stride
      } else {
        // Store at least 16 elements per block.
        blockSize = 16
      }
    }
    buff = DoubleEndedBuffer<Block>(capacity: 16, with: .middle)
    buff.pushBack(Block(capacity: blockSize, with: .middle))
    count = 0
  }

  /// True iff no values are contained in `self.
  public var isEmpty: Bool { count == 0 }

  private mutating func reallocateBuff() {
    if buff.count * 2 < buff.capacity {
      // Reallocate to the same size to avoid taking too much memory.
      buff.reallocate(newCapacity: buff.capacity, with: .middle)
    } else {
      buff.reallocate(newCapacity: buff.capacity * 2, with: .middle)
    }
  }

  /// Add `elem` to the back of `self`.
  public mutating func pushBack(_ elem: Element) {
    count += 1
    if buff[buff.endIndex - 1].canPushBack {
      buff[buff.endIndex - 1].pushBack(elem)
    } else {
      if buff[buff.endIndex - 1].isEmpty {
        // Re-use the previous buffer.
        buff[buff.endIndex - 1].pushFront(elem)
      } else {
        // Allocate a new buffer.
        var newBlock = Block(capacity: buff[buff.endIndex - 1].capacity, with: .beginning)
        newBlock.pushBack(elem)
        if !buff.canPushBack {
          reallocateBuff()
        }
        buff.pushBack(newBlock)
      }
    }
  }

  /// Removes and returns the element at the back, reducing `self`'s count by one.
  ///
  /// - Precondition: !isEmpty
  public mutating func popBack() -> Element {
    assert(!isEmpty, "Cannot popBack from an empty Deque.")
    count -= 1
    let tmp = buff[buff.endIndex - 1].popBack()
    if buff[buff.endIndex - 1].isEmpty && buff.count > 1 {
      _ = buff.popBack()
    }
    return tmp
  }

  /// Adds `elem` to the front of `self`.
  public mutating func pushFront(_ elem: Element) {
    count += 1
    if buff[buff.startIndex].canPushFront {
      buff[buff.startIndex].pushFront(elem)
    } else {
      // Allocate a new buffer.
      var newBlock = Block(capacity: buff[buff.startIndex].capacity, with: .end)
      newBlock.pushFront(elem)
      if !buff.canPushFront {
        reallocateBuff()
      }
      buff.pushFront(newBlock)
    }
  }

  /// Removes and returns the element at the front, reducing `self`'s count by one.
  ///
  /// - Precondition: !isEmpty
  public mutating func popFront() -> Element {
    precondition(!isEmpty)
    count -= 1
    let tmp = buff[buff.startIndex].popFront()
    if buff[buff.startIndex].isEmpty && buff.count > 1 {
      _ = buff.popFront()
    }
    return tmp
  }
}

extension Deque: Queue {
  public mutating func pop() -> Element? {
    if isEmpty {
      return nil
    }
    return popFront()
  }

  public mutating func push(_ element: Element) {
    pushBack(element)
  }
}

extension Deque: HierarchicalCollection {

  public struct Cursor: Equatable, Comparable {
    let outerIndex: Int
    let innerIndex: Int

    public static func < (lhs: Self, rhs: Self) -> Bool {
      if lhs.outerIndex < rhs.outerIndex { return true }
      if lhs.outerIndex > rhs.outerIndex { return false }
      return lhs.innerIndex < rhs.innerIndex
    }
  }

  /// Call `fn` for each element in the collection until `fn` returns false.
  ///
  /// - Parameter start: Start iterating at elements corresponding to this index. If nil, starts at
  ///   the beginning of the collection.
  /// - Returns: a cursor into the data structure corresponding to the first element that returns
  ///   false.
  @discardableResult
  public func forEachWhile(
    startingAt start: Cursor?,
    _ fn: (Element) throws -> Bool
  ) rethrows -> Cursor? {
    let startPoint =
      start
      ?? Cursor(
        outerIndex: buff.startIndex,
        innerIndex: buff[buff.startIndex].startIndex)

    /// Start with potential partial first buffer.
    for i in startPoint.innerIndex..<buff[startPoint.outerIndex].endIndex {
      let shouldContinue = try fn(buff[startPoint.outerIndex][i])
      if !shouldContinue {
        return Cursor(outerIndex: startPoint.outerIndex, innerIndex: i)
      }
    }
    // Nested loops for remainder of data structure.
    for outer in (startPoint.outerIndex + 1)..<buff.endIndex {
      for inner in buff[outer].startIndex..<buff[outer].endIndex {
        let shouldContinue = try fn(buff[outer][inner])
        if !shouldContinue {
          return Cursor(outerIndex: outer, innerIndex: inner)
        }
      }
    }
    return nil
  }
}
