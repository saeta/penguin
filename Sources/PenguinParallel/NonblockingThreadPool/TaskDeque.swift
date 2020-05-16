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

/// A fixed-size, partially non-blocking deque of `Element`s.
///
/// Operations on the front of the deque must be done by a single thread (the "owner" thread), and
/// these operations never block. Operations on the back of the queue can be done by multiple
/// threads concurrently (however they are serialized through a mutex).
internal class TaskDeque<Element, Environment: ConcurrencyPlatform>: ManagedBuffer<
  TaskDequeHeader<Environment>,
  TaskDequeElement<Element>
>
{

  // TaskDeque keeps all non-empty elements in a contiguous buffer.

  class func make() -> Self {
    precondition(
      Constants.capacity > 3 && Constants.capacity <= 65536,
      "capacity must be between [4, 65536].")
    precondition(
      Constants.capacity & (Constants.capacity - 1) == 0,
      "capacity must be a power of two for fast masking.")
    let deque = Self.create(minimumCapacity: Constants.capacity) { _ in TaskDequeHeader() } as! Self
    deque.withUnsafeMutablePointerToElements { elems in
      elems.initialize(repeating: TaskDequeElement(), count: Constants.capacity)
    }
    return deque
  }

  deinit {
    assert(
      TaskDequeIndex(header.front.valueRelaxed).index
        == TaskDequeIndex(header.back.valueRelaxed).index,
      "TaskDeque not empty; \(self)")
  }

  /// Add a new element to the front of the queue.
  ///
  /// - Invariant: this function must only be ever called by the "owner" thread.
  /// - Returns: an `Element` if the queue is full; it is up to the caller to appropriately execute
  ///   the returned element.
  func pushFront(_ elem: Element) -> Element? {
    withUnsafeMutablePointerToElements { elems in
      let front = TaskDequeIndex(header.front.valueRelaxed)
      var state = elems[front.index].state.valueRelaxed
      if TaskState(rawValue: state) != .empty
        || !elems[front.index].state.cmpxchgStrongAcquire(
          original: &state, newValue: TaskState.busy.rawValue)
      {
        return elem
      }
      header.front.setRelaxed(front.movedForward().underlying)
      elems[front.index].element = elem
      elems[front.index].state.setRelease(TaskState.ready.rawValue)
      return nil
    }
  }

  /// Removes one element from the front of the queue.
  ///
  /// - Invariant: this function must only ever be called by the "owner" thread.
  /// - Returns: an `Element` if the queue is non-empty.
  func popFront() -> Element? {
    withUnsafeMutablePointerToElements { elems in
      let front = TaskDequeIndex(header.front.valueRelaxed).movedBackward()
      var state = elems[front.index].state.valueRelaxed
      if TaskState(rawValue: state) != .ready
        || !elems[front.index].state.cmpxchgStrongAcquire(
          original: &state, newValue: TaskState.busy.rawValue)
      {
        return nil
      }
      var elem: Element? = nil
      swap(&elems[front.index].element, &elem)
      elems[front.index].state.setRelease(TaskState.empty.rawValue)
      header.front.setRelaxed(front.underlying)
      return elem
    }
  }

  /// Add a new element to the back of the queue.
  ///
  /// This function can be called from any thread.
  /// - Returns: an `Element` if the queue is full; it is up to the caller to appropriately execute
  ///   the returned element.
  func pushBack(_ elem: Element) -> Element? {
    withUnsafeMutablePointerToElements { elems in
      header.lock.lock()
      defer { header.lock.unlock() }

      let back = TaskDequeIndex(header.back.valueRelaxed).movedBackward()
      var state = elems[back.index].state.valueRelaxed
      if TaskState(rawValue: state) != .empty
        || !elems[back.index].state.cmpxchgStrongAcquire(
          original: &state, newValue: TaskState.busy.rawValue)
      {
        return elem
      }
      header.back.setRelaxed(back.underlying)
      elems[back.index].element = elem
      elems[back.index].state.setRelease(TaskState.ready.rawValue)
      return nil
    }
  }

  /// Removes one element from the back of the queue.
  ///
  /// This function can be called from any thread.
  /// - Returns: an `Element` if the queue is non-empty.
  func popBack() -> Element? {
    if isEmpty { return nil }  // Fast-path to avoid taking lock.

    return withUnsafeMutablePointerToElements { elems in
      header.lock.lock()
      defer { header.lock.unlock() }

      let back = TaskDequeIndex(header.back.valueRelaxed)
      var state = elems[back.index].state.valueRelaxed
      if TaskState(rawValue: state) != .ready
        || !elems[back.index].state.cmpxchgStrongAcquire(
          original: &state, newValue: TaskState.busy.rawValue)
      {
        return nil
      }
      var elem: Element? = nil
      swap(&elems[back.index].element, &elem)
      elems[back.index].state.setRelease(TaskState.empty.rawValue)
      header.back.setRelaxed(back.movedForward().underlying)
      return elem
    }
  }

  /// False iff the queue contains at least one entry.
  ///
  /// Note: this operation is carefully implemented such that it can be relied upon for concurrent
  /// coordination. It is guaranteed to never return true if there is a valid entry.
  ///
  /// This property can be accessed from any thread.
  var isEmpty: Bool {
    header.isEmpty
  }
}

struct TaskDequeHeader<Environment: ConcurrencyPlatform> {
  /// Points to first beyond valid element.
  var front: AtomicUInt64
  var padding1: UInt64 = 0
  var padding2: UInt64 = 0
  var padding3: UInt64 = 0
  var padding4: UInt64 = 0
  var padding5: UInt64 = 0
  var padding6: UInt64 = 0
  var padding7: UInt64 = 0
  var padding8: UInt64 = 0
  var padding9: UInt64 = 0
  var padding10: UInt64 = 0
  var padding11: UInt64 = 0
  var padding12: UInt64 = 0
  var padding13: UInt64 = 0
  var padding14: UInt64 = 0
  var padding15: UInt64 = 0
  /// Points to the last valid element.
  var back: AtomicUInt64
  let lock: Environment.Mutex  // Lock is used by `back`-accessing threads.

  init() {
    lock = Environment.Mutex()
    // Note: when front & back are equal, the deque is empty.
    front = AtomicUInt64()
    back = AtomicUInt64()
  }

  var isEmpty: Bool {
    mutating get {
      // Because emptiness plays a critical role in thread pool blocking, the isEmpty implementation
      // is careful to avoid producing false positives (i.e. claiming non-empty queue as empty).
      var f = front.valueAcquire
      while true {
        // Capture a consistent snapshot of f & b
        let b = back.valueAcquire
        let f2 = front.valueRelaxed
        if f != f2 {
          f = f2  // Try again.
          threadFenceAcquire()
          continue
        }
        // We now have a consistent shapshot.
        return TaskDequeIndex(f).index == TaskDequeIndex(b).index
      }
    }
  }
}

struct TaskDequeElement<Element> {
  var element: Element?
  var state: AtomicUInt8

  init() {
    element = nil
    state = AtomicUInt8()
  }
}

/// The layout of the underlying atomic value is: 
fileprivate struct TaskDequeIndex {
  var underlying: UInt64
  init(_ underlying: UInt64) { self.underlying = underlying }

  var index: Int { Int(underlying & Self.indexMask) }

  func movedForward() -> Self {
    Self(underlying + Self.increment)
  }

  func movedBackward() -> Self {
    Self((underlying &- 1) & Self.indexMask | (underlying & ~Self.indexMask))
  }

  // Every time we move forward, we bump an additional sequence counter. This allows us to avoid
  // ABA problems
  static var increment: UInt64 { UInt64(Constants.capacity << 2 + 1) }

  // Mask to determine the valid indices.
  static var indexMask: UInt64 { UInt64(Constants.capacity) - 1 }
}

extension TaskDequeIndex: CustomStringConvertible {
  public var description: String {
    "TaskDequeIndex(\(index), \(underlying >> Constants.capacityBits))"
  }
}

fileprivate enum TaskState: UInt8 {
  case empty
  case ready
  case busy
}

fileprivate enum Constants {
  /// The fixed size of the TaskDeque.
  static var capacityBits: Int { 10 }
  static var capacity: Int { 1 << capacityBits }
}

extension TaskDeque: CustomDebugStringConvertible {
  public var debugDescription: String {
    let front = TaskDequeIndex(header.front.valueRelaxed)
    let back = TaskDequeIndex(header.back.valueRelaxed)

    return "TaskDeque(front: \(front), back: \(back))"
  }
}
