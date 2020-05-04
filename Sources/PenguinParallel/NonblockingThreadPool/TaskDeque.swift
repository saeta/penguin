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

fileprivate let kDequeSize = 1024

/// A fixed-size, partially non-blocking deque of `Element`s.
///
/// Operations on the front of the deque must be done by a single thread (the "owner" thread), and
/// these operations never block. Operations on the back of the queue can be done by multiple
/// threads concurrently (however they are serialized through a mutex).
///
/// Note: the current implementation is just a stub!
class TaskDeque<Element, Environment: ConcurrencyPlatform>: ManagedBuffer<
  TaskDequeHeader<Environment>,
  TaskDequeElement<Element>
> {

  // TaskDeque keeps all non-empty elements in a contiguous 

  class func make() -> Self {
    precondition(kDequeSize > 3 && kDequeSize <= 65536, "kDequeSize must be between [4, 65536].")
    precondition(
      kDequeSize & (kDequeSize - 1) == 0,
      "kDequeSize must be a power of two for fast masking.")
    let deque = Self.create(minimumCapacity: kDequeSize) { _ in TaskDequeHeader() } as! Self
    deque.withUnsafeMutablePointerToElements { elems in
      elems.initialize(repeating: TaskDequeElement(element: nil, state: 0), count: kDequeSize)
    }
    // TODO: initialize the elements!
    return deque
  }

  deinit {
    assert(header.front == header.back, "TaskDeque not empty!")
  }

  /// Add a new element to the front of the queue.
  ///
  /// - Invariant: this function must only be ever called by the "owner" thread.
  /// - Returns: an `Element` if the queue is full; it is up to the caller to appropriately execute
  ///   the returned element.
  func pushFront(_ elem: Element) -> Element? {
    header.lock.lock()
    defer { header.lock.unlock() }

    let newFront = (header.front + 1) & (kDequeSize - 1)
    if newFront == header.back {
      return elem
    }
    withUnsafeMutablePointerToElements { elems in
      assert(elems[header.front].element == nil)
      elems[header.front].element = elem
    }
    header.front = newFront
    return nil
  }

  /// Removes one element from the front of the queue.
  ///
  /// - Invariant: this function must only ever be called by the "owner" thread.
  /// - Returns: an `Element` if the queue is non-empty.
  func popFront() -> Element? {
    header.lock.lock()
    defer { header.lock.unlock() }
    if header.front == header.back { return nil }
    let newFront = (header.front - 1) & (kDequeSize - 1)
    header.front = newFront
    return withUnsafeMutablePointerToElements { elems in
      var elem: Element? = nil
      swap(&elems[header.front].element, &elem)
      assert(elem != nil)
      return elem
    }
  }

  /// Add a new element to the back of the queue.
  ///
  /// This function can be called from any thread.
  /// - Returns: an `Element` if the queue is full; it is up to the caller to appropriately execute
  ///   the returned element.
  func pushBack(_ elem: Element) -> Element? {
    header.lock.lock()
    defer { header.lock.unlock() }

    let newBack = (header.back - 1) & (kDequeSize - 1)
    if newBack == header.front {
      return elem
    }
    withUnsafeMutablePointerToElements { elems in
      assert(elems[newBack].element == nil)
      elems[newBack].element = elem
    }
    header.back = newBack
    return nil
  }
  
  /// Removes one element from the back of the queue.
  ///
  /// This function can be called from any thread.
  /// - Returns: an `Element` if the queue is non-empty.
  func popBack() -> Element? {
    header.lock.lock()
    defer { header.lock.unlock() }
    if header.front == header.back { return nil }
    let newBack = (header.back + 1) & (kDequeSize - 1)
    defer { header.back = newBack }
    return withUnsafeMutablePointerToElements { elems in
      var elem: Element? = nil
      swap(&elems[header.back].element, &elem)
      assert(elem != nil)
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
  init() {
    lock = Environment.Mutex()
    front = 0  // Points to first beyond valid element.
    back = 0  // Points to last valid element.
  }

  let lock: Environment.Mutex
  // TODO: convert these to atomic variables & ensure they are aligned appropriately to avoid false
  // sharing!
  // Note: when front & back are equal, the deque is empty.
  var front: Int
  var back: Int

  var isEmpty: Bool {
    lock.lock()
    defer { lock.unlock() }
    return front == back
  }
}

struct TaskDequeElement<Element> {
  var element: Element?
  var state: UInt8  // TODO: convert to enum & make atomic!
}
