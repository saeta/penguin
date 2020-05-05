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

/// Allows to wait for arbitrary predicates in non-blocking algorithms.
///
/// You can think of `NonblockingCondition` as a condition variable, but the predicate to wait upon
/// does not need to be protected by a mutex. Using `NonblockingCondition` in a non-blocking
/// algorithm (instead of spinning) allows threads to go sleep, saving potentially significant
/// amounts of CPU resources.
///
/// To use `NonblockingCondition`, your algorithm should look like the following:
///
/// ```
/// let nbc = NonblockingCondition(...) 
///
/// // Waiting thread:
/// if predicate { return doWork() }
/// nbc.preWait(threadId)
/// if predicate {
///	  nbc.cancelWait(threadId)
///   return doWork()
/// }
/// nbc.commitWait(threadId)  // Puts current thread to sleep until notified.
///
/// // Notifying thread:
/// predicate = true
/// nbc.notify()  // or nbc.notifyAll()
/// ```
///
/// Notifying is cheap if there are no waiting threads. preWait and commitWait are not cheap, but
/// they should only be executed if the preceding predicate check failed. This yields an efficient
/// system in the general case where there is low contention.
final public class NonblockingCondition<Environment: ConcurrencyPlatform> {
  // Algorithm outline:
  //
  // There are two main variables: the predicate (which is managed by the user of
  // NonblockingCondition), and state. The operation closely resembles the Dekker algorithm:
  // https://en.wikipedia.org/wiki/Dekker%27s_algorithm.
  //
  // The waiting thread sets state, and checks predicate. The notifying thread sets the predicate
  // and then checks state. Due to the seq_cst fences in between these operations, it is guaranteed
  // that either the waiter will see the predicate change and won't block, or the notifying thread
  // will see the state change, and will unblock the waiter, or both. But it is impossible that both
  // threads don't see each other's changes, as that would lead to a deadlock.
  //
  // This implementation is heavily inspired by event_count.h from the Eigen library.

  /// The atomic storage backing the state of this non blocking condition.
  private var stateStorage: AtomicUInt64

  /// Per-thread state, including the condition variable used to sleep the corresponding thread.
  fileprivate let threads: ThreadsState

  /// Threads begin in the notSignaled state. When they are about to go to sleep, they enter the
  /// waiting state. When they should wake up, the state changes to the signaled state.
  enum PerThreadState {
    case notSignaled
    case waiting
    case signaled
  }

  /// Per-thread state.
  struct PerThread {
    /// `next` encodes a stack of waiting threads.
    var nextStorage = AtomicUInt64()
    /// epoch is regularly incremented, and is used to avoid the ABA problem.
    var epoch: UInt64 = 0
    /// The current state of the corresponding thread.
    var state: PerThreadState = .notSignaled
    /// Condition used to sleep the corresponding thread.
    let cond = Environment.ConditionMutex()
    /// Padding to ensure no false sharing of the atomic values.
    let padding: (UInt64, UInt64) = (0, 0)  // Unused; can't use @_alignment to ensure spacing.

    init() {
      nextStorage.setRelaxed(NonblockingConditionState.stackMask)
    }

    var next: UInt64 {
      mutating get {
        nextStorage.valueRelaxed
      }
      set {
        nextStorage.setRelaxed(newValue)
      }
    }
  }

  /// A buffer containing elements.
  ///
  /// Note: we cannot use an Array, as value semantics is inappropriate for this algorithm.
  final class ThreadsState: ManagedBuffer<Void, PerThread> {
    class func make(_ threadCount: Int) -> Self {
      let obj = Self.create(minimumCapacity: threadCount) { _ in () }
      obj.withUnsafeMutablePointerToElements { elems in
        for ptr in elems..<(elems + obj.capacity) {
          ptr.initialize(to: PerThread())
        }
      }
      return obj as! Self
    }
    deinit {
      withUnsafeMutablePointerToElements { _ = $0.deinitialize(count: capacity) }
    }

    subscript(index: Int) -> PerThread {
      _read { yield withUnsafeMutablePointerToElements { $0[index] } }
      _modify {
        let ptr = withUnsafeMutablePointerToElements { $0 + index }
        yield &ptr.pointee
      }
    }
  }

  /// Initializes NonblockingCondition for use by up to `threadCount` waiters.
  public init(threadCount: Int) {
    stateStorage = AtomicUInt64()
    stateStorage.setRelaxed(NonblockingConditionState.stackMask)  // Empty stack.
    threads = ThreadsState.make(threadCount)
  }

  deinit {
    let state = loadAcquire()
    precondition(state.stackIsEmpty, "\(state)")
    precondition(state.preWaitCount == 0, "\(state)")
    precondition(state.signalCount == 0, "\(state)")
  }

  /// Wakes up waiters.
  ///
  /// `notify` is optimized to be cheap in the common case where there are no threads to wake up.
  public func notify(all: Bool = false) {
    threadFenceSeqCst()
    var state = loadAcquire()
    while true {
      state.checkSelf()
      if state.stackIsEmpty && state.preWaitCount == state.signalCount { return }  // Fast path.

      var newState = state
      if all {
        newState.notifyAll()
      } else if state.signalCount < state.preWaitCount {
        newState.incrementSignalCount()
      } else if !state.stackIsEmpty {
        // Pop a waiter from the stack and unpark it.
        let next = threads[state.stackTop].next
        newState.popStack(newNext: next)
      }
      newState.checkSelf()
      if cmpxchgAcqRel(originalState: &state, newState: newState) {
        if !all && state.signalCount < state.preWaitCount {
          return  // There is already an unblocked pre-wait thread. Nothing more to do!
        }
        if state.stackIsEmpty { return }  // Nothing more to do.
        if !all {
          // Set the next pointer in stack top to the empty stack, because we only want to wake up
          // one thread.
          threads[state.stackTop].next = NonblockingConditionState.stackMask
        }
        unparkStack(state.stackTop)
        return
      }
    }
  }

  /// Signals an intent to wait.
  public func preWait() {
    var state = loadRelaxed()
    while true {
      state.checkSelf()
      let newState = state.incrementPreWaitCount()
      newState.checkSelf()
      if compxchgSeqCst(originalState: &state, newState: newState) { return }
    }
  }

  /// Cancels an intent to wait (i.e. the awaited condition occurred.)
  public func cancelWait() {
    var state = loadRelaxed()
    while true {
      state.checkSelf(mustHavePreWait: true)
      var newState = state.decrementPreWaitCount()
      // Because we don't know if the thread was notified or not, we should not consume a signal
      // token unconditionally. Instead, if the number of preWait tokens was equal to the number of
      // signal tokens, then we know that we must consume a signal token.
      if state.signalCount == state.preWaitCount {
        newState.decrementSignalCount()
      }
      newState.checkSelf()
      if cmpxchgAcqRel(originalState: &state, newState: newState) { return }
    }
  }

  /// Puts the current thread to sleep until a notification occurs.
  public func commitWait(_ threadId: Int) {
    assert(
      (threads[threadId].epoch & ~NonblockingConditionState.epochMask) == 0,
      "State for \(threadId) is invalid.")
    threads[threadId].state = .notSignaled
    let epoch = threads[threadId].epoch

    var state = loadSeqCst()
    while true {
      state.checkSelf(mustHavePreWait: true)
      let newState: NonblockingConditionState
      if state.hasSignal {
        newState = state.consumeSignal()
      } else {
        newState = state.updateForWaitCommit(threadId, epoch: epoch)
        threads[threadId].next = state.nextToken
      }
      newState.checkSelf()
      if cmpxchgAcqRel(originalState: &state, newState: newState) {
        if !state.hasSignal {
          // No signal, so we must wait.
          threads[threadId].epoch += NonblockingConditionState.epochIncrement
          park(threadId)
        }
        return
      }
    }
  }

  /// Parks the current thread of execution (identifed as `threadId`) until notified.
  private func park(_ threadId: Int) {
    threads[threadId].cond.lock()
    threads[threadId].cond.await {
      if threads[threadId].state == .signaled { return true }
      threads[threadId].state = .waiting
      return false
    }
    threads[threadId].cond.unlock()
  }

  /// Unparks the stack of thread ids, starting at `threadId`.
  private func unparkStack(_ threadId: Int) {
    var index = threadId
    // NonblockingConditionState.stackMask is the sentinal for the bottom of the stack.
    while index != NonblockingConditionState.stackMask {
      threads[index].cond.lock()
      threads[index].state = .signaled
      let nextIndex = Int(threads[index].next & NonblockingConditionState.stackMask)
      threads[index].next = NonblockingConditionState.stackMask  // Set to empty.
      threads[index].cond.unlock()
      index = nextIndex
    }
  }

  private func loadRelaxed() -> NonblockingConditionState {
    NonblockingConditionState(stateStorage.valueRelaxed)
  }

  private func loadAcquire() -> NonblockingConditionState {
    NonblockingConditionState(stateStorage.valueAcquire)
  }

  private func loadSeqCst() -> NonblockingConditionState {
    NonblockingConditionState(stateStorage.valueSeqCst)
  }

  private func cmpxchgAcqRel(
    originalState: inout NonblockingConditionState,
    newState: NonblockingConditionState
  ) -> Bool {
    stateStorage.cmpxchgAcqRel(original: &originalState.underlying, newValue: newState.underlying)
  }

  private func compxchgSeqCst(
    originalState: inout NonblockingConditionState,
    newState: NonblockingConditionState
  ) -> Bool {
    stateStorage.cmpxchgSeqCst(original: &originalState.underlying, newValue: newState.underlying)
  }
}

/// A single UInt64 encoding the critical state of the `NonblockingCondition`.
///
/// UInt64 Format:
///   - low counterBits points to the top of the stack of parked waiters (index in the threads
///     array).
///   - next counterBits is the count of waiters in the preWait state.
///   - next counterBits is the count of pending signals.
///   - remaining bits are ABA counter for the stack, and are incremented when a new value is pushed
///     onto the stack.
fileprivate struct NonblockingConditionState {
  var underlying: UInt64

  init(_ underlying: UInt64) { self.underlying = underlying }

  /// Perform a number of consistency checks to maintain invariants.
  ///
  /// Note: this function should be optimized away in release builds.
  func checkSelf(
    mustHavePreWait: Bool = false,
    oldState: Self? = nil,
    file: StaticString = #file,
    line: UInt = #line,
    function: StaticString = #function
  ) {
    assert(Self.epochBits >= 20, "not enough bits to prevent the ABA problem!")
    assert(
      preWaitCount >= signalCount,
      "preWaitCount < signalCount \(self) (discovered in \(function) at: \(file):\(line)\(oldState != nil ? " oldState: \(oldState!)" : ""))"
    )
    assert(
      !mustHavePreWait || preWaitCount > 0,
      "preWaitCount was 0: \(self) (discovered in \(function) at: \(file):\(line)\(oldState != nil ? " oldState: \(oldState!)" : ""))"
    )
  }

  /// The thread at the top of the stack.
  var stackTop: Int { Int(underlying & Self.stackMask) }
  var stackIsEmpty: Bool { (underlying & Self.stackMask) == Self.stackMask }

  /// The number of threads in the pre-wait state.
  var preWaitCount: UInt64 {
    (underlying & Self.waiterMask) >> Self.waiterShift
  }

  /// Increments the pre-wait count by one.
  func incrementPreWaitCount() -> Self {
    Self(underlying + Self.waiterIncrement)
  }

  /// Reduce the pre-wait count by one.
  func decrementPreWaitCount() -> Self {
    Self(underlying - Self.waiterIncrement)
  }

  /// The number of signals queued in the condition.
  var signalCount: UInt64 {
    (underlying & Self.signalMask) >> Self.signalShift
  }

  /// True iff there is a singal waiting.
  var hasSignal: Bool { (underlying & Self.signalMask) != 0 }

  mutating func incrementSignalCount() {
    underlying += Self.signalIncrement
  }

  mutating func decrementSignalCount() {
    underlying -= Self.signalIncrement
  }

  /// Consumes a preWait token and a signal token.
  func consumeSignal() -> Self {
    Self(underlying - (Self.waiterIncrement + Self.signalIncrement))
  }

  /// Consumes a prewait counter, and adds `threadId` to the waiter stack.
  func updateForWaitCommit(_ threadId: Int, epoch: UInt64) -> Self {
    assert(threadId >= 0, "\(threadId)")
    assert(threadId < Self.stackMask, "\(threadId)")
    assert(!hasSignal, "\(self)")

    // We set the stack pointer to `threadId`, decrement the `waiter` count, and set the ABA epoch.
    let tmp = (underlying & Self.waiterMask) - Self.waiterIncrement
    return Self(tmp + UInt64(threadId) + epoch)
  }

  mutating func notifyAll() {
    // Empty wait stack and set signal to # of pre wait threads, keep the preWait count the same.
    underlying =
      (underlying & Self.waiterMask) | (preWaitCount << Self.signalShift) | Self.stackMask
    assert(stackIsEmpty, "\(self)")
    assert(signalCount == preWaitCount, "\(self)")
  }

  mutating func popStack(newNext: UInt64) {
    underlying = (underlying & (Self.waiterMask | Self.signalMask)) | newNext
  }

  /// Token to be used in the implicit stack.
  var nextToken: UInt64 { underlying & (Self.stackMask | Self.epochMask) }

  var epoch: UInt64 { underlying & Self.epochMask }

  static let counterBits: UInt64 = 14
  static let counterMask: UInt64 = (1 << counterBits) - 1

  static let stackMask: UInt64 = counterMask

  static let waiterShift: UInt64 = counterBits
  static let waiterMask: UInt64 = counterMask << waiterShift
  static let waiterIncrement: UInt64 = 1 << waiterShift

  static let signalShift: UInt64 = 2 * counterBits
  static let signalMask: UInt64 = counterMask << signalShift
  static let signalIncrement: UInt64 = 1 << signalShift

  static let epochShift: UInt64 = 3 * counterBits
  static let epochBits: UInt64 = 64 - epochShift
  static let epochMask: UInt64 = ((1 << epochBits) - 1) << epochShift
  static let epochIncrement: UInt64 = 1 << epochShift
}

extension NonblockingConditionState: CustomStringConvertible {
  public var description: String {
    "NonblockingConditionState(stackTop: \(stackTop), preWaitCount: \(preWaitCount), signalCount: \(signalCount), epoch: \(epoch >> Self.epochShift))"
  }
}

extension NonblockingCondition.PerThread {
  mutating func makeDescription() -> String {
    "PerThread(state: \(state), epoch: \(epoch >> NonblockingConditionState.epochShift), next: \(next))"
  }
}

extension NonblockingCondition.ThreadsState: CustomStringConvertible {
  public var description: String {
    var s = "["
    withUnsafeMutablePointerToElements { elems in
      for i in 0..<capacity {
        s.append("\n  \(i): \(elems[i].makeDescription())")
      }
    }
    s.append("\n]")
    return s
  }
}

extension NonblockingCondition: CustomDebugStringConvertible {
  public var debugDescription: String {
    "NonblockingCondition(state: \(loadRelaxed()), threads: \(threads))"
  }
}
