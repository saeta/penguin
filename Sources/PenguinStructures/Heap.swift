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

/// Indexes a heap data structure for efficient modification of element priority.
///
/// Algorithms using priority queues sometimes need to adjust the priority of elements within the
/// priority queue during the course of the algorithm's execution. For example, as new edges are
/// discovered during a Dijkstra's search, distance to verticies in the queue are reduced, thus
/// increasing their priority. `ConfigurableHeap` supports reprioritization, but requires a data
/// structure with efficient lookup from `Element` to `Index`. This protocol abstracts over
/// `ConfigurableHeap`'s requirements.
///
/// Note: due to a limitation in Swift's subscripting, we cannot support a `subscript` that only
/// contains a `set` (and not a `get`). As a result, we must use a second protocol that refines
/// this protocol (`_ConfigurableHeapIndexer`) to mark whether `get` is supported.
///
/// - SeeAlso: `ConfigurableHeap`
/// - SeeAlso: `_ConfigurableHeapIndexer`
public protocol _ConfigurableHeapIndexerProtocol {
  /// The elements contained within the Heap.
  associatedtype Element
  /// The index type to refer to where in the heap's internal data structure the element exists.
  associatedtype Index

  /// Maps from element to location within the data structure; if `newValue` is `nil`, removes
  /// `elem` from `self`.
  ///
  /// Note: this protocol would ideally only require `set`. `get` is logically added by conforming
  /// to `_ConfigurableHeapIndexer`.
  subscript(elem: Element) -> Index? { get set }
}

/// No-op index for a `ConfigurableHeap`.
public struct _NullHeapIndexer<Element, Index>: _ConfigurableHeapIndexerProtocol,
  DefaultInitializable
{
  /// Initialize an empty `self`.
  public init() {}

  /// No-op indexing operations.
  public subscript(elem: Element) -> Index? {
    get { nil }
    set { /* do nothing */  }
  }
}

/// Represents `get` and `set` for `_ConfigurableHeapIndexerProtocol`.
public protocol _ConfigurableHeapIndexer: _ConfigurableHeapIndexerProtocol {}

/// Indexes a `ConfigurableHeap` of `Element`s.
public struct _DictionaryHeapIndexer<Element: Hashable, Index>: _ConfigurableHeapIndexer,
  DefaultInitializable
{
  /// Hash table to implement the indexing.
  private var dictionary = [Element: Index]()

  /// Initializes an empty dictionary heap indexer.
  public init() {}

  /// Indexing opreations.
  public subscript(elem: Element) -> Index? {
    get {
      dictionary[elem]
    }
    set {
      dictionary[elem] = newValue
    }
  }
}

/// Indexes a `ConfigurableHeap` of `Element`s, so long as the element is `IdIndexible`.
public struct _IdIndexibleDictionaryHeapIndexer<
  Element: IdIndexable, Index
>: _ConfigurableHeapIndexer, DefaultInitializable {
  /// Hash table to implement the indexing.
  private var dictionary = [Int: Index]()

  /// Initializes an empty heap indexer.
  public init() {}

  /// Indexing operations.
  public subscript(elem: Element) -> Index? {
    get {
      dictionary[elem.index]
    }
    set {
      dictionary[elem.index] = newValue
    }
  }
}

/// A logical pointer into `ConfigurableHeap`'s internal data structures.
///
/// - SeeAlso: `HierarchicalCollection`.
public struct _ConfigurableHeapCursor<Index: BinaryInteger> {
  let index: Index
}

// MARK: - Heaps

/// A basic heap data structure containing `Element`s.
///
/// Note: `Element`s within `self` do not need to be unique.
public typealias SimpleHeap<Element> = ConfigurableHeap<
  Element, Int, Int32, _NullHeapIndexer<Element, _ConfigurableHeapCursor<Int32>>
>

/// A heap that supports reprioritizinig elements contained within it.
///
/// - Invariant: `Element`s within `self` must be unique.
public typealias ReprioritizableHeap<Element: Hashable> = ConfigurableHeap<
  Element, Int, Int32, _DictionaryHeapIndexer<Element, _ConfigurableHeapCursor<Int32>>
>

/// A hierarchical collection of `Element`s, partially ordered so that finding the minimum element
/// can be done in constant time.
///
/// If `Indexer` conforms to both `_ConfigurableHeapIndexerProtocol` and `_ConfigurableHeapIndexer`,
/// this heap data structure supports re-prioritizing elements contained within it.
public struct ConfigurableHeap<
  Element,
  Priority: Comparable,
  Index: BinaryInteger,  // TODO: change to hierarchical cursor!
  Indexer: _ConfigurableHeapIndexerProtocol
> where Indexer.Index == _ConfigurableHeapCursor<Index>, Indexer.Element == Element {

  /// A logical pointer into the `ConfigurableHeap`'s internal data structures.
  public typealias Cursor = _ConfigurableHeapCursor<Index>

  // TODO: convert to B-Heap instead of binary-heap.
  /// The buffer containing the elements of `self`.
  ///
  /// - Invariant: elements are ordered in a full, binary tree implicitly within the array, such
  ///   that the parent is of lower priority than its two children.
  private var buffer = [(Element, Priority)]()
  private var indexer: Indexer

  /// Initialize an empty heap using `indexer` for indexing.
  public init(indexer: Indexer) {
    self.indexer = indexer
  }

  /// The number of elements 
  public var count: Int {
    buffer.count
  }

  /// True iff there are no elements within `self`.
  public var isEmpty: Bool {
    count == 0
  }

  /// Adds `elem` with the specified `priority` to `self`.
  public mutating func add(_ elem: Element, with priority: Priority) {
    assert(indexer[elem] == nil, "\(elem) already in `self`.")
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
  public mutating func popFrontWithPriority() -> (element: Element, priority: Priority)? {
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
        indexer[buffer[i].0] = Cursor(index: Index(i))
        i = p
      } else {
        indexer[buffer[i].0] = Cursor(index: Index(i))  // Ensure we've updated the index.
        return  // We're done!
      }
    }
  }

  /// Performs a series of swap's to restore the invariants of the data structure.
  private mutating func sinkDown(startingAt index: Int) {
    guard !isEmpty else { return }
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
        indexer[buffer[i].0] = Cursor(index: Index(i))
        return  // Done!
      }
      buffer.swapAt(i, minIndex)
      indexer[buffer[i].0] = Cursor(index: Index(i))
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

extension ConfigurableHeap: DefaultInitializable where Indexer: DefaultInitializable {
  /// Initialize an empty Heap.
  public init() {
    self.init(indexer: Indexer())
  }
}

extension ConfigurableHeap where Indexer: _ConfigurableHeapIndexer {
  /// Updates the priority of `elem` to `newPriority`.
  ///
  /// - Precondition: `elem` is contained within `self`.
  /// - Complexity: O(log n)
  /// - Returns: the original (previous) priority of `elem`.
  @discardableResult
  public mutating func update(_ elem: Element, withNewPriority newPriority: Priority) -> Priority {
    guard let originalPosition = indexer[elem] else {
      preconditionFailure("\(elem) was not found within `self`.")
    }
    let originalPriority = buffer[Int(originalPosition.index)].1
    buffer[Int(originalPosition.index)].1 = newPriority
    if originalPriority < newPriority {
      sinkDown(startingAt: Int(originalPosition.index))
    } else {
      bubbleUp(startingAt: Int(originalPosition.index))
    }
    return originalPriority
  }
}

extension ConfigurableHeap: CustomStringConvertible {
  /// A string representation of the heap, including priorities of the elements.
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
