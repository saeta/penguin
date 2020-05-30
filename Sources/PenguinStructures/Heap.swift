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

// MARK: - Heap algorithms

extension RandomAccessCollection where Self: MutableCollection, Element: Comparable {

  /// A callback to facilitate indexing a heap.
  ///
  /// All operations that modify the position of elements within the min-heap take an optional
  /// `HeapChangeListener` that is called once for every element that is moved during the heap
  /// modification. This flexibility allows some heap implementations to keep track of the
  /// locations of elements within the heap, allowing for efficient reprioritization.
  public typealias HeapChangeListener = (_ justMoved: Element, _ newIndex: Index?) -> Void

  /// Reorders `self` as a [binary heap](https://en.wikipedia.org/wiki/Heap_(data_structure))
  /// with a minimal element at the top.
  public mutating func reorderAsMinHeap(changeListener: HeapChangeListener = { _, _ in } ) {
    for i in (0...((count + 1) / 2)).reversed() {
      minHeapSinkDown(startingAt: index(startIndex, offsetBy: i), changeListener: changeListener)
    }
  }

  /// Establishes a binary heap relationship between `index` and its children.
  ///
  /// - Precondition: binary heap invariants are satisfied for both of `index`'s children.
  /// - Parameter changeListener: A callback invoked with the element and new position of any
  ///   moved element.
  /// - Complexity: O(log n)
  public mutating func minHeapSinkDown(
    startingAt index: Index,
    changeListener: HeapChangeListener
  ) {
    var i = index
    while true {
      var minIndex = i
      if let lhs = leftChild(of: i), self[lhs] < self[minIndex] {
        minIndex = lhs
      }
      if let rhs = rightChild(of: i), self[rhs] < self[minIndex] {
        minIndex = rhs
      }
      if minIndex == i {
        changeListener(self[minIndex], minIndex)
        return  // Done!
      }
      swapAt(i, minIndex)
      changeListener(self[i], i)
      i = minIndex  // Keep going to see if more work is necessary.
    }    
  }

  /// Restores binary heap invariants when `index` becomes lesser.
  ///
  /// - Precondition: binary heap invariants are satisfied everywhere in `self` except at `index`.
  /// - Parameter changeListener: A callback invoked with the element and new position of any moved
  ///   element.
  /// - Complexity: O(log n)
  public mutating func minHeapBubbleUp(
    startingAt index: Index,
    changeListener: HeapChangeListener
  ) {
    var i = index
    while true {
      let p = parent(of: i)
      if self[i] < self[p] {
        swapAt(p, i)
        changeListener(self[i], i)
        i = p
      } else {
        changeListener(self[i], i)  // Ensure we've updated the index.
        return  // We're done!
      }
    }
  }
}

extension RandomAccessCollection
where Self: MutableCollection & RangeReplaceableCollection, Element: Comparable {

  /// Adds `element` into `self` while maintaining min-heap invariants.
  ///
  /// - Parameter element: the item to insert into the min-heap.
  /// - Parameter changeListener: (Optional) A callback to record updated locations of elements in
  ///   `self`. Default: a no-op listener.
  /// - Precondition: `isMinHeap` (checked only in debug builds).
  /// - Postcondition: `isMinHeap`.
  /// - Complexity: O(log `count`).
  public mutating func insertMinHeap(
    _ element: Element,
    changeListener: HeapChangeListener = { _, _ in }
  ) -> Void {
    assert(isMinHeap)
    append(element)
    minHeapBubbleUp(startingAt: index(before: endIndex), changeListener: changeListener)
  }

  /// Removes and returns the minimum element from `self` while maintaining minheap invariants.
  ///
  /// - Parameter changeListener: (Optional) A callback to record updated locations of elements in
  ///   `self`. Default: a no-op listener.
  /// - Precondition: `isMinHeap` (checked only in debug builds).
  /// - Postcondition: `isMinHeap`.
  /// - Complexity: O(log `count`).
  public mutating func popMinHeap(changeListener: HeapChangeListener = { _, _ in } ) -> Element? {
    assert(isMinHeap)
    guard !isEmpty else { return nil }
    swapAt(startIndex, index(before: endIndex))
    let minElement = popLast()!
    if !isEmpty {
      minHeapSinkDown(startingAt: startIndex, changeListener: changeListener)
    }
    changeListener(minElement, nil)
    return minElement
  }
}

extension RandomAccessCollection where Element: Comparable {
  /// `true` iff `self` is arranged as a [binary
  /// min-heap](https://en.wikipedia.org/wiki/Binary_heap).
  public var isMinHeap: Bool {
    for offset in 0..<((count + 1) / 2) {
      let i = index(startIndex, offsetBy: offset)
      if let l = leftChild(of: i), self[i] > self[l] {
        return false
      }
      if let r = rightChild(of: i), self[i] > self[r] {
        return false
      }
    }
    return true
  }

  // TODO: move the following functions to be in a protocol to allow certain data structures
  // (such as a B-Heap) to provide more efficient implementations.

  /// Computes the index of the parent of `i`.
  fileprivate func parent(of i: Index) -> Index {
    let parentOffset = (distance(from: startIndex, to: i) - 1) / 2
    return index(startIndex, offsetBy: parentOffset)
  }

  /// Computes the left child of `i`, if it exists.
  private func leftChild(of i: Index) -> Index? {
    let childOffset = 2 * distance(from: startIndex, to: i) + 1
    guard childOffset < count else { return nil }
    return index(startIndex, offsetBy: childOffset)
  }

  /// Computes the right child of `i`, if it exists.
  private func rightChild(of i: Index) -> Index? {
    let childOffset = 2 * distance(from: startIndex, to: i) + 2
    guard childOffset < count else { return nil }
    return index(startIndex, offsetBy: childOffset)
  }
}

// MARK: - Priority Queue

/// Lookup and storage of values based on a key.
// Note: We can't use `Index` because that clashes with `Collection.Index`.
public protocol IndexProtocol {
  /// The key used to store and retrieve data.
  associatedtype Key
  /// The data we intend to store.
  associatedtype Value

  /// Accesses the `Value` associated with `key`.
  subscript(key: Key) -> Value? { get set }
}

/// A comparable tuple containing a comparable priority and an arbitrary payload.
public struct PriorityQueueElement<Priority: Comparable, Payload> {
  /// The priority of the payload.
  public var priority: Priority
  /// The element 
  public let payload: Payload

  public init(priority: Priority, payload: Payload) {
    self.priority = priority
    self.payload = payload
  }
}

extension PriorityQueueElement: Equatable, Comparable {
  /// Returns `true` if the priorities of `lhs` and `rhs` are equal, false otherwise.
  public static func == (lhs: Self, rhs: Self) -> Bool {
    return lhs.priority == rhs.priority
  }

  /// Returns `true` if the priority of `lhs` is lower than the priority of `rhs`.
  public static func < (lhs: Self, rhs: Self) -> Bool {
    return lhs.priority < rhs.priority
  }
}

/// Indexes from `Key` to `Value`.
///
/// - SeeAlso: `IndexProtocol`.
/// - Note: this is intentionally distinct from `IndexProtocol`, in order to statically disallow
///   PriorityQueue's reprioritization APIs when using a `NonIndexingPriorityQueueIndexer` indexer.
public protocol PriorityQueueIndexer {
  /// The key used to store and retrieve data.
  associatedtype Key
  /// The data we intend to store.
  associatedtype Value

  /// Accesses the `Value` associated with `key`.
  subscript(key: Key) -> Value? { get set }  // Note: ideally this would be "set-only", but can't.
}

extension Dictionary: PriorityQueueIndexer, IndexProtocol {}

/// Adapts a collection indexed by `Int`s into a `PriorityQueueIndexer` and `IndexProtocol`.
///
/// - SeeAlso: `ArrayPriorityQueueIndexer`.
public struct CollectionPriorityQueueIndexer<
  Key: IdIndexable,
  Table: RandomAccessCollection & MutableCollection,
  Value
>: PriorityQueueIndexer, IndexProtocol
where Table.Index == Int, Table.Element == Value?
{
  /// The collection that stores the mappings from `Int`s to `Value?`s.
 public var table: Table

  /// Constrcuts `self` by wrapping `table`.
  public init(_ table: Table) {
    self.table = table
  }

  /// Accesses the value associated with `key`.
  public subscript(key: Key) -> Value? {
    get { table[key.index] }
    set { table[key.index] = newValue }
  }
}

extension CollectionPriorityQueueIndexer: DefaultInitializable where Table: DefaultInitializable {
  /// Default initialization.
  public init() {
    self.init(.init())
  }
}

/// Indexes priority queues using an `Array`, where the PriorityQueue's Payloads are `IdIndexable`.
public typealias ArrayPriorityQueueIndexer<Key: IdIndexable, Value> =
  CollectionPriorityQueueIndexer<Key, [Value?], Value>

extension ArrayPriorityQueueIndexer {
  /// Initializes an empty table for up to `count` keys.
  public init(count: Int) {
    self.init(Array<Value?>(repeating: nil, count: count) as! Table)  // ???
  }
}

/// A zero-sized type that does no indexing, and can be used when re-prioritization within a
/// `PriorityQueue` is not needed.
public struct NonIndexingPriorityQueueIndexer<Key, Value>: PriorityQueueIndexer, DefaultInitializable {
  public init() {}
  public subscript(key: Key) -> Value? {
    get { fatalError("Cannot get values out of a `NonIndexingPriorityQueueIndexer`.") }
    set { /* no-op */ }
  }
}

/// A collection of `Priority`s and `Payload`s that allows for efficient retrieval of the smallest
/// priority and its associated payload, and insertion of payloads at arbitrary priorities.
///
/// This is a min-priority queue, where `a` has "higher priority" than `b` if `a < b`.
///
/// - SeeAlso: `SimplePriorityQueue`.
public struct GenericPriorityQueue<
  Priority: Comparable,
  Payload,
  Heap: RandomAccessCollection & RangeReplaceableCollection & MutableCollection,
  ElementLocations: PriorityQueueIndexer
>: Queue where
  Heap.Element == PriorityQueueElement<Priority, Payload>,
  ElementLocations.Key == Payload,
  ElementLocations.Value == Heap.Index
{
  /// The type of data in the underlying binary heap.
  public typealias Element = PriorityQueueElement<Priority, Payload>

  /// The heap data structure containing our priority queue.
  public var heap: Heap

  /// An index from items to an `Index` in `heap`.
  private var locations: ElementLocations

  public init(heap: Heap, locations: ElementLocations) {
    self.heap = heap
    self.locations = locations
  }

  /// The data at the top of the priority queue.
  public var top: Payload? {
    guard !heap.isEmpty else { return nil }
    return heap[heap.startIndex].payload
  }

  /// Removes and returns the top of 
  @discardableResult
  public mutating func pop() -> Element? {
    return heap.popMinHeap { locations[$0.payload] = $1 }
  }

  /// Adds `element` into `self` and updates the internal data structures to maintain efficiency.
  public mutating func push(_ element: Element) {
    heap.insertMinHeap(element) { locations[$0.payload] = $1 }
  }

  /// Adds `payload` into `self` at priority level `priority`, and updates the internal data
  /// structures to maintain efficiency.
  public mutating func push(_ payload: Payload, at priority: Priority) {
    push(Element(priority: priority, payload: payload))
  }
}

extension GenericPriorityQueue: RandomAccessCollection {
  // TODO: Pass through more of the R-A-C methods to heap to potentially improve efficiency.

  public var startIndex: Heap.Index { heap.startIndex }
  public var endIndex: Heap.Index { heap.endIndex }
  public subscript(index: Heap.Index) -> Element { heap[index] }
  public func index(after index: Heap.Index) -> Heap.Index { heap.index(after: index) }
  public func index(before index: Heap.Index) -> Heap.Index { heap.index(before: index) }
}

/// A GenericPriorityQueue with useful defaults pre-specified.
///
/// - SeeAlso: `GenericPriorityQueue`.
public typealias SimplePriorityQueue<Payload> =
  GenericPriorityQueue<
    Int,
    Payload,
    [PriorityQueueElement<Int, Payload>],
    NonIndexingPriorityQueueIndexer<Payload, Int>>

/// A PriorityQueue with useful defaults pre-specified.
///
/// - SeeAlso: `GenericPriorityQueue`.
public typealias PriorityQueue<Payload, Priority: Comparable> =
  GenericPriorityQueue<
    Priority,
    Payload,
    [PriorityQueueElement<Priority, Payload>],
    NonIndexingPriorityQueueIndexer<Payload, Int>>

/// A `GenericPriorityQueue` that uses a `Dictionary` to index the location of `Payload`s to allow for
/// efficient updates to a `Payload`'s priority.
///
/// Note: every `Payload` in `self` must not equal any other `Payload` in `self`.
public typealias ReprioritizablePriorityQueue<Payload: Hashable, Priority: Comparable> = 
  GenericPriorityQueue<
    Priority,
    Payload,
    [PriorityQueueElement<Priority, Payload>],
    Dictionary<Payload, Int>>

extension GenericPriorityQueue: DefaultInitializable
where
  Heap: DefaultInitializable,
  ElementLocations: DefaultInitializable
{

  /// Constructs an empty GenericPriorityQueue.
  public init() {
    self.heap = Heap()
    self.locations = ElementLocations()
  }
}

extension GenericPriorityQueue where ElementLocations: DefaultInitializable {
  /// Constructs a GenericPriorityQueue from `heap`.
  ///
  /// - Precondition: `heap.isMinHeap`
  public init(_ heap: Heap) {
    precondition(heap.isMinHeap, "Heap was not a min-heap.")
    self.heap = heap
    self.locations = ElementLocations()
    // Wire up locations.
    for i in heap.indices {
      locations[heap[i].payload] = i
    }
  }
}

extension GenericPriorityQueue where ElementLocations: IndexProtocol {
  /// Updates the priority of `payload` to `newPriority`.
  ///
  /// - Precondition: `payload` is contained within `self`.
  /// - Complexity: O(log n)
  /// - Returns: the previous priority of `elem`.
  @discardableResult
  public mutating func update(_ payload: Payload, withNewPriority newPriority: Priority) -> Priority {
    guard let originalPosition = locations[payload] else {
      preconditionFailure("\(payload) was not found within `self`.")
    }
    let originalPriority = heap[originalPosition].priority
    heap[originalPosition].priority = newPriority
    if originalPriority < newPriority {
      heap.minHeapSinkDown(startingAt: originalPosition) { locations[$0.payload] = $1 }
    } else {
      heap.minHeapBubbleUp(startingAt: originalPosition) { locations[$0.payload] = $1 }
    }
    return originalPriority
  }  
}

extension GenericPriorityQueue: CustomStringConvertible {
  /// A string representation of the heap, including priorities of the elements.
  public var description: String {
    var str = ""
    for (i, index) in heap.indices.enumerated() {
      str.append(" - \(i): p\(heap[index].priority) (\(heap[index].payload))")
      if i != 0 {
        let p = parent(of: index)
        str.append(" parent: @ p\(heap[p].priority)")
      }
      str.append("\n")
    }
    return str
  }
}
