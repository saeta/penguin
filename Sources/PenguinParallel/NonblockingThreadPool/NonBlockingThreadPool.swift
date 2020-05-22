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

import PenguinStructures

/// An efficient, work-stealing, general purpose compute thread pool.
///
/// `NonBlockingThreadPool` can be cleaned up by calling `shutDown()` which will block until all
/// threads in the threadpool have exited. If `shutDown()` is never called, `NonBlockingThreadPool`
/// will never be deallocated.
///
/// NonBlockingThreadPool uses atomics to implement a non-blocking thread pool. During normal
/// execution, no locks are acquired or released. This can result in efficient parallelism across
/// many cores. `NonBlockingThreadPool` is designed to scale from laptops to high-core-count
/// servers. Although the thread pool size can be manually tuned, often the most efficient
/// configuration is a one-to-one mapping between hardware threads and worker threads, as this
/// allows full use of the hardware while avoiding unnecessary context switches. I/O heavy workloads
/// may want to reduce the thread pool count to dedicate a core or two to I/O processing.
///
/// Each thread managed by this thread pool maintains its own fixed-size pending task queue. The
/// workers loop, trying to get their next tasks from their own queue first, and if that queue is
/// empty, the worker tries to steal work from the pending task queues of other threads in the pool.
///
/// `NonBlockingThreadPool` implements important optimizations based on the calling thread. There
/// are key fast-paths taken when calling functions on `NonBlockingThreadPool` from threads that
/// have been registered with the pool (or from threads managed by the pool itself). In order
/// to help users build performant applications, `NonBlockingThreadPool` will trap (and exit the
/// process) if functions are called on it from non-fast-path'd threads by default. You can change
/// this behavior by setting `allowNonFastPathThreads: true` at initialization.
///
/// In order to avoid wasting excessive CPU cycles, the worker threads managed by
/// `NonBlockingThreadPool` will suspend themselves (using locks to inform the host kernel).
/// `NonBlockingThreadPool` is parameterized by an environment, which allows this thread pool to
/// seamlessly interoperate within a larger application by reusing its concurrency primitives (such
/// as locks and condition variables, which are used for thread parking), as well as even allowing
/// a custom thread allocator.
///
/// Local tasks typically execute in LIFO order, which is often optimal for cache locality of
/// compute intensive tasks. Other threads attempt to steal work "FIFO"-style, which admits an
/// efficient (dynamic) schedule for typical divide-and-conquor algorithms.
///
/// This implementation is inspired by the Eigen thread pool library, TFRT, as well as:
///
///     "Thread Scheduling for Multiprogrammed Multiprocessors"
///     Nimar S. Arora, Robert D. Blumofe, C. Greg Plaxton
///
public class NonBlockingThreadPool<Environment: ConcurrencyPlatform>: ComputeThreadPool {
  public typealias Task = () -> Void
  public typealias ThrowingTask = () throws -> Void
  fileprivate typealias Queue = TaskDeque<PoolTask, Environment>

  let allowNonFastPathThreads: Bool
  let totalThreadCount: Int
  let externalFastPathThreadCount: Int
  var externalFastPathThreadSeenCount: Int = 0
  let coprimes: [Int]
  fileprivate let queues: [Queue]
  var cancelledStorage: AtomicUInt64
  var blockedCountStorage: AtomicUInt64
  var spinningState: AtomicUInt64
  var condition: NonblockingCondition<Environment>
  var waitingMutex: [Environment.ConditionMutex]  // TODO: modify condition to add per-thread wakeup
  var externalWaitingMutex: Environment.ConditionMutex
  var threads: [Environment.Thread]

  private let perThreadKey = Environment.ThreadLocalStorage.makeKey(
    for: PerThreadState<Environment>.self)

  /// Initialize a new thread pool with `threadCount` threads using threading environment
  /// `environment`.
  ///
  /// - Parameter name: a human-readable name for the threadpool.
  /// - Parameter threadCount: the number of worker threads in the thread pool.
  /// - Parameter environment: an instance of the environment.
  /// - Parameter externalFastPathThreadCount: the maximum number of external threads with fast-path
  ///   access to the threadpool.
  /// - Parameter allowNonFastPathThreads: true if non-fast-path'd threads are allowed to submit
  ///   work into the pool or not. (Note: non-fast-path'd threads can always dispatch work into the
  ///   pool.)
  public init(
    name: String,
    threadCount: Int,
    environment: Environment,
    externalFastPathThreadCount: Int = 1,
    allowNonFastPathThreads: Bool = false
  ) {
    assert(_isPOD(PoolTask.self), "PoolTask should be a POD type for performance.")
    self.allowNonFastPathThreads = allowNonFastPathThreads
    let totalThreadCount = threadCount + externalFastPathThreadCount
    self.totalThreadCount = totalThreadCount
    self.externalFastPathThreadCount = externalFastPathThreadCount
    self.coprimes = makeCoprimes(upTo: totalThreadCount)
    self.queues = (0..<totalThreadCount).map { _ in Queue.make() }
    self.cancelledStorage = AtomicUInt64()
    self.blockedCountStorage = AtomicUInt64()
    self.spinningState = AtomicUInt64()
    self.condition = NonblockingCondition(threadCount: threadCount)  // Only block pool threads.
    self.waitingMutex = (0..<totalThreadCount).map { _ in Environment.ConditionMutex() }
    self.externalWaitingMutex = Environment.ConditionMutex()
    self.threads = []

    for i in 0..<threadCount {
      threads.append(
        environment.makeThread(name: "\(name)-\(i)-of-\(threadCount)") {
          Self.workerThread(state: PerThreadState(threadId: i, pool: self))
        })
    }

    // Register current thread as a fast-path thread.
    registerCurrentThread()
  }

  deinit {
    // Shut ourselves down, just in case.
    shutDown()
  }

  /// Registers the current thread with the thread pool for fast-path operation.
  public func registerCurrentThread() {
    externalWaitingMutex.lock()
    defer { externalWaitingMutex.unlock() }
    let threadId = threads.count + externalFastPathThreadSeenCount
    externalFastPathThreadSeenCount += 1
    let state = PerThreadState(threadId: threadId, pool: self)
    perThreadKey.localValue = state
  }

  public func dispatch(_ fn: @escaping Task) {
    let holder = Unmanaged.passRetained(DispatchTaskHolder(fn))
    let poolTask = PoolTask.dispatch(holder)
    if let local = perThreadKey.localValue {
      // Push onto local queue.
      if !queues[local.threadId].pushFront(poolTask) {
        // If local queue is full, execute immediately.
        holder.takeRetainedValue().fn()
      } else {
        wakeupWorkerIfRequired()
      }
    } else {
      // Called not from within the threadpool; pick a victim thread from the pool at random.
      // TODO: use a faster RNG!
      let victim = Int.random(in: 0..<queues.count)
      if !queues[victim].pushBack(poolTask) {
        // If queue is full, execute inline.
        holder.takeRetainedValue().fn()
      } else {
        wakeupWorkerIfRequired()
      }
    }
  }

  public func join(_ a: Task, _ b: Task) {
    // add `b` to the work queue (and execute it immediately if queue is full).
    // if added to the queue, maybe wakeup worker if required.
    //
    // then execute `a`.
    //
    // while `b` hasn't yet completed, do work locally, or do work remotely. Once the background
    // task has completed, it will atomically set a bit in the local data structure, and we can
    // then continue execution.
    //
    // If we should park ourselves to wait for `b` to finish executing and there's absolutely no
    // work we can do ourselves, we wait on the current thread's ConditionMutex. When `b` is
    // finally available, the completer must trigger the ConditionMutex.
    withoutActuallyEscaping(b) { b in
      var joinTask = JoinTask(b)
      withUnsafeMutablePointer(to: &joinTask) { joinTask in
        let poolTask = PoolTask.join(joinTask)
        let perThread = perThreadKey.localValue  // Stash in stack variable for performance.

        // Enqueue `b` into a work queue.
        if let localThreadIndex = perThread?.threadId {
          // Push to front of local queue.
          if queues[localThreadIndex].pushFront(poolTask) {
            wakeupWorkerIfRequired()
          } else {
            // Execute inline immediately.
            b()
            joinTask.pointee.stateStorage.setRelaxed(JoinTaskState.completedMask)  // Mark complete.
          }
        } else {
          precondition(
            allowNonFastPathThreads,
            """
            Non-fast-path thread disallowed. (Set `allowNonFastPathThreads: true` when initializing
            \(String(describing: type(of: self))) to allow `join` to be called from non-registered
            threads. Note: this may make debugging performance problems more difficult.)
            """)
          let victim = Int.random(in: 0..<queues.count)
          // push to back of victim queue.
          if queues[victim].pushBack(poolTask) {
            wakeupWorkerIfRequired()
          } else {
            // Execute inline immediately.
            b()
            joinTask.pointee.stateStorage.setRelaxed(JoinTaskState.completedMask)  // Mark complete.
          }
        }

        // Execute `a`.
        a()

        if let perThread = perThread {
          // Thread pool thread... execute work on the threadpool.
          let q = queues[perThread.threadId]
          // While `b` is not done, try and be useful
          while !joinTask.pointee.isDoneAcquiring() {
            if let task = q.popFront() ?? perThread.steal() ?? perThread.spin() {
              perThread.execute(task)
            } else {
              // No work to be done without blocking, so we block ourselves specially.
              // This state occurs when another thread stole `b`, but hasn't finished and there's
              // nothing else useful for us to do.
              waitingMutex[perThread.threadId].lock()
              // Set our handle in the joinTask's state.
              var state = JoinTaskState(joinTask.pointee.stateStorage.valueRelaxed)
              while !state.isDone {
                let newState = state.settingWakeupThread(perThread.threadId)
                if joinTask.pointee.stateStorage.cmpxchgAcqRel(
                  original: &state.underlying, newValue: newState.underlying)
                {
                  break
                }
              }
              if !state.isDone {
                waitingMutex[perThread.threadId].await {
                  joinTask.pointee.isDoneAcquiring()  // What about cancellation?
                }
              }
              waitingMutex[perThread.threadId].unlock()
            }
          }
        } else {
          // Do a quick check to see if we can fast-path return...
          if !joinTask.pointee.isDoneAcquiring() {
            // We ran on the user's thread, so we now wait on the pool's global lock.
            externalWaitingMutex.lock()
            // Set the sentinal thread index.
            var state = JoinTaskState(joinTask.pointee.stateStorage.valueRelaxed)
            while !state.isDone {
              let newState = state.settingWakeupThread(-1)
              if joinTask.pointee.stateStorage.cmpxchgAcqRel(
                original: &state.underlying, newValue: newState.underlying)
              {
                break
              }
            }
            if !state.isDone {
              externalWaitingMutex.await {
                joinTask.pointee.isDoneAcquiring()  // What about cancellation?
              }
            }
            externalWaitingMutex.unlock()
          }
        }
      }
    }
  }

  public func join(_ a: ThrowingTask, _ b: ThrowingTask) throws {
    // Because the implementation doesn't support early cancellation of tasks (extra coordination
    // overhead not worth it for the normal case of non-throwing execution), we implement the
    // throwing case in terms of the non-throwing case.
    var err: Error? = nil
    let lock = Environment.Mutex()
    join(
      {
        do { try a() } catch {
          lock.lock()
          err = error
          lock.unlock()
        }
      },
      {
        do { try b() } catch {
          lock.lock()
          err = error
          lock.unlock()
        }
      })
    if let e = err { throw e }
  }

  public func parallelFor(n: Int, _ fn: VectorizedParallelForFunction) {

    withoutActuallyEscaping(fn) { fn in
      if let perThread = perThreadKey.localValue {
            var task = ParallelForTask(parallelForFunction: fn, total: n)
        withUnsafeMutablePointer(to: &task) { task in
          // Run locally.
          let grainSize = n / parallelism  // TODO: Make adaptive!
          perThread.executeParallelForTask(task, start: 0, end: n, grainSize: grainSize)
        }
      } else {
        // Attempt to foist it onto the thread pool & block until it's done.
        precondition(
          allowNonFastPathThreads,
          """
          Non-fast-path thread disallowed. (Set `allowNonFastPathThreads: true` when initializing
          \(String(describing: type(of: self))) to allow `join` to be called from non-registered
          threads. Note: this may make debugging performance problems more difficult.)
          """)
        let doneCondition = Environment.ConditionMutex()
        var isDone = false
        doneCondition.lock()
        dispatch { [self] in
          self.parallelFor(n: n, fn)
          doneCondition.lock()
          isDone = true
          doneCondition.unlock()
        }
        doneCondition.await { isDone }
        doneCondition.unlock()
      }
    }
  }

  public func parallelFor(n: Int, _ fn: ThrowingVectorizedParallelForFunction) throws {
    var err: Error? = nil
    let lock = Environment.Mutex()

    parallelFor(n: n) { start, end, total in
      do {
        try fn(start, end, total)
      } catch {
        lock.lock()
        if err != nil {
          err = error
        }
        lock.unlock()
      }
    }

    if let err = err { throw err }
  }

  /// Shuts down the thread pool.
  public func shutDown() {
    cancelled = true
    condition.notify(all: true)
    // Wait until each thread has stopped.
    for thread in threads {
      thread.join()
    }
    threads.removeAll()  // Remove threads that have been shut down.
  }

  public var parallelism: Int { totalThreadCount }

  public var currentThreadIndex: Int? {
    perThreadKey.localValue?.threadId
  }
}

extension NonBlockingThreadPool {

  /// Controls whether the thread pool threads should exit and shut down.
  fileprivate var cancelled: Bool {
    get {
      cancelledStorage.valueRelaxed == 1
    }
    set {
      assert(newValue == true)
      cancelledStorage.setRelaxed(1)
    }
  }

  /// The number of threads that are blocked on a condition.
  fileprivate var blockedThreadCount: Int { Int(blockedCountStorage.valueRelaxed) }
  /// The number of threads that are actively executing.
  fileprivate var activeThreadCount: Int { threads.count - blockedThreadCount }

  /// Wakes up a worker if required.
  ///
  /// This function should be called right after adding a new task to a per-thread queue.
  ///
  /// If there are threads spinning in the steal loop, there is no need to unpark a waiting thread,
  /// as the task will get picked up by one of the spinners.
  fileprivate func wakeupWorkerIfRequired() {
    var state = NonBlockingSpinningState(spinningState.valueRelaxed)
    while true {
      // if the number of tasks submitted without notifying parked threads is equal to the number of
      // spinning threads, we must wake up one of the parked threads
      if state.noNotifyCount == state.spinningCount {
        condition.notify()
        return
      }
      let newState = state.incrementingNoNotifyCount()
      if spinningState.cmpxchgRelaxed(original: &state.underlying, newValue: newState.underlying) {
        return
      }
    }
  }

  /// Called to determine if a thread should start spinning.
  fileprivate func shouldStartSpinning() -> Bool {
    if activeThreadCount > Constants.minActiveThreadsToStartSpinning { return false }  // ???

    var state = NonBlockingSpinningState(spinningState.valueRelaxed)
    while true {
      if (state.spinningCount - state.noNotifyCount) >= Constants.maxSpinningThreads {
        return false
      }
      let newState = state.incrementingSpinningCount()
      if spinningState.cmpxchgRelaxed(original: &state.underlying, newValue: newState.underlying) {
        return true
      }
    }
  }

  /// Called when a thread stops spinning.
  ///
  /// - Returns: `true` if there is a task to steal; false otherwise.
  fileprivate func stopSpinning() -> Bool {
    var state = NonBlockingSpinningState(spinningState.valueRelaxed)
    while true {
      var newState = state.decrementingSpinningCount()

      // If there was a task submitted without notifying a thread, try to claim it.
      let noNotifyTask = state.hasNoNotifyTask
      if noNotifyTask { newState.decrementNoNotifyCount() }

      if spinningState.cmpxchgRelaxed(original: &state.underlying, newValue: newState.underlying) {
        return noNotifyTask
      }
    }
  }

  /// The worker thread's run loop.
  private static func workerThread(state: PerThreadState<Environment>) {
    state.pool.perThreadKey.localValue = state

    let q = state.pool.queues[state.threadId]
    while !state.isCancelled {
      if let task = q.popFront() ?? state.steal() ?? state.spin() ?? state.parkUntilWorkAvailable()
      {
        state.execute(task)  // Execute the task.
      }
    }
  }
}

extension NonBlockingThreadPool where Environment: DefaultInitializable {
  /// Creates `self` using a default-initialized `Environment`, and the specified `name` and
  /// `threadCount`.
  public convenience init(name: String, threadCount: Int) {
    self.init(name: name, threadCount: threadCount, environment: Environment())
  }
}

// TODO: switch to a struct, and operate via pointer to avoid additional ARC traffic.
fileprivate final class PerThreadState<Environment: ConcurrencyPlatform> {
  typealias Task = NonBlockingThreadPool<Environment>.Task

  init(threadId: Int, pool: NonBlockingThreadPool<Environment>) {
    self.threadId = threadId
    self.workerThreadCount = pool.totalThreadCount - pool.externalFastPathThreadCount
    self.pool = pool
    self.rng = PCGRandomNumberGenerator(state: UInt64(threadId))
    self.queue = pool.queues[threadId]
  }
  let threadId: Int
  let workerThreadCount: Int
  let queue: NonBlockingThreadPool<Environment>.Queue
  let pool: NonBlockingThreadPool<Environment>  // Note: this creates a reference cycle.
  // The reference cycle is okay, because you just call `pool.shutDown()`, which will deallocate the
  // threadpool.
  //
  // Note: because you cannot dereference an object in Swift that is in it's `deinit`, it is not
  // possible to provide a safer API that doesn't leak by default without inducing an extra pointer
  // dereference on critical paths. :-(

  var rng: PCGRandomNumberGenerator

  var isCancelled: Bool { pool.cancelled }

  func steal() -> PoolTask? {
    let r = Int(rng.next())
    var selectedThreadId = fastFit(r, into: pool.totalThreadCount)
    let step = pool.coprimes[fastFit(r, into: pool.coprimes.count)]
    assert(
      step < pool.totalThreadCount, "step: \(step), pool threadcount: \(pool.totalThreadCount)")

    for i in 0..<pool.totalThreadCount {
      assert(
        selectedThreadId < pool.totalThreadCount,
        "\(selectedThreadId) is too big on iteration \(i); max: \(pool.totalThreadCount), step: \(step)"
      )
      if let task = pool.queues[selectedThreadId].popBack() {
        return task
      }
      selectedThreadId += step
      if selectedThreadId >= pool.totalThreadCount {
        selectedThreadId -= pool.totalThreadCount
      }
    }
    return nil
  }

  func spin() -> PoolTask? {
    let spinCount = workerThreadCount > 0 ? Constants.spinCount / workerThreadCount : 0

    if pool.shouldStartSpinning() {
      // Call steal spin_count times; break if steal returns something.
      for _ in 0..<spinCount {
        if let task = steal() {
          _ = pool.stopSpinning()
          return task
        }
      }
      // Stop spinning & optionally make one more check.
      let existsNoNotifyTask = pool.stopSpinning()
      if existsNoNotifyTask {
        return steal()
      }
    }
    return nil
  }

  func parkUntilWorkAvailable() -> PoolTask? {
    // Already did a best-effort emptiness check in steal, so prepare for blocking.
    pool.condition.preWait()
    // Now we do a reliable emptiness check.
    if let nonEmptyQueueIndex = findNonEmptyQueueIndex() {
      pool.condition.cancelWait()
      // Steal from `nonEmptyQueueIndex`.
      return pool.queues[nonEmptyQueueIndex].popBack()
    }
    let blockedCount = pool.blockedCountStorage.increment() + 1  // increment returns old value.
    if blockedCount == pool.threads.count {
      // TODO: notify threads that could be waiting for "all blocked" event. (Useful for quiescing.)
    }
    if isCancelled {
      pool.condition.cancelWait()
      return nil
    }
    pool.condition.commitWait(threadId)
    _ = pool.blockedCountStorage.decrement()
    return nil
  }

  private func findNonEmptyQueueIndex() -> Int? {
    let r = Int(rng.next())
    let increment =
      pool.totalThreadCount == 1 ? 1 : pool.coprimes[fastFit(r, into: pool.coprimes.count)]
    var threadIndex = fastFit(r, into: pool.totalThreadCount)
    for _ in 0..<pool.totalThreadCount {
      if !pool.queues[threadIndex].isEmpty { return threadIndex }
      threadIndex += increment
      if threadIndex >= pool.totalThreadCount {
        threadIndex -= pool.totalThreadCount
      }
    }
    return nil
  }

  func execute(_ task: PoolTask) {
    assert(threadId == pool.currentThreadIndex,
      "Internal error: `execute(_:)` must only be called on a thread pool thread.")
    switch task {
      case .dispatch(let holder): holder.takeRetainedValue().fn()
      case .join(let task): executeJoinTask(task)
      case .parallelFor(let slice): executeParallelForTaskSlice(slice)
    }
  }

  func executeJoinTask(_ task: UnsafeMutablePointer<JoinTask>) {
    assert(!task.pointee.isDoneAcquiring(), "JoinTask was done before even starting execution.")
    task.pointee.op()  // Execute the function.
    var state = JoinTaskState(task.pointee.stateStorage.valueRelaxed)
    while true {
      assert(!state.isDone, "state: \(state)")
      let newState = state.markingDone()
      if task.pointee.stateStorage.cmpxchgAcqRel(
        original: &state.underlying, newValue: newState.underlying)
      {
        if let wakeupThread = state.wakeupThread {
          // Do a lock & unlock on the corresponding thread lock.
          if wakeupThread != -1 {
            pool.waitingMutex[wakeupThread].lock()
            pool.waitingMutex[wakeupThread].unlock()
          } else {
            pool.externalWaitingMutex.lock()
            pool.externalWaitingMutex.unlock()
          }
        }
        return
      }
    }
  }

  func executeParallelForTaskSlice(_ task: UnsafeMutablePointer<ParallelForTaskSlice>) {
    executeParallelForTask(
      task.pointee.task,
      start: task.pointee.start,
      end: task.pointee.end,
      grainSize: task.pointee.grainSize)
    // Mark the task as done.
    var state = JoinTaskState(task.pointee.stateStorage.valueRelaxed)
    while true {
      assert(!state.isDone, "state: \(state)")
      let newState = state.markingDone()
      if task.pointee.stateStorage.cmpxchgAcqRel(original: &state.underlying, newValue: newState.underlying) {
        if let wakeupThread = state.wakeupThread {
          // Do a lock & unlock on the corresponding thread lock to wake it up.
          if wakeupThread != -1 {
            pool.waitingMutex[wakeupThread].lock()
            pool.waitingMutex[wakeupThread].unlock()
          } else {
            pool.externalWaitingMutex.lock()
            pool.externalWaitingMutex.unlock()
          }
        }
        return
      }
    }
  }

  func executeParallelForTask(_ task: UnsafePointer<ParallelForTask>, start: Int, end: Int, grainSize: Int) {
    assert(end > start, "Unexpected start (\(start)) and end (\(end)).")
    if end - start <= grainSize {
      // Just execute the function.
      task.pointee.parallelForFunction(start, end, task.pointee.total)
    } else {
      // Divide in half, and execute in parallel.
      let distance = end - start
      let midPoint = start + (distance / 2)

      var slice = ParallelForTaskSlice(
        task: task,
        start: midPoint,
        end: end,
        grainSize: grainSize)
      withUnsafeMutablePointer(to: &slice) { slice in
        guard queue.pushFront(.parallelFor(slice)) else {
          // If we bounce, just do the whole task inline.
          task.pointee.parallelForFunction(start, end, task.pointee.total)
          return
        }
        pool.wakeupWorkerIfRequired()
        // Execute local half using recrsion.
        executeParallelForTask(task, start: start, end: midPoint, grainSize: grainSize)
        // Do work until the other half is done (including possibly doing the work ourselves).
        while !slice.pointee.isDoneAcquiring() {
          if let task = queue.popFront() ?? steal() ?? spin() {
            execute(task)
          } else {
            // No work to be done without blocking, so we block ourselves specially.
            pool.waitingMutex[threadId].lock()
            defer { pool.waitingMutex[threadId].unlock() }
            // Set our handle in the state.
            var state = JoinTaskState(slice.pointee.stateStorage.valueRelaxed)
            while !state.isDone {
              let newState = state.settingWakeupThread(threadId)
              if slice.pointee.stateStorage.cmpxchgAcqRel(original: &state.underlying, newValue: newState.underlying) {
                break
              }
            }
            if !state.isDone {
              pool.waitingMutex[threadId].await { slice.pointee.isDoneAcquiring() }
            }
          }
        }
      }
    }
  }
}

fileprivate enum PoolTask {
  case dispatch(Unmanaged<DispatchTaskHolder>)
  case join(UnsafeMutablePointer<JoinTask>)
  case parallelFor(UnsafeMutablePointer<ParallelForTaskSlice>)
}

/// Holds a dispatch task.
///
/// We wrap the `fn` closure in a class so we can use `Unmanaged` to ensure that `PoolTask` is a
/// POD type, which optimizes better.
fileprivate class DispatchTaskHolder {
  init(_ fn: @escaping () -> ()) {
    self.fn = fn
  }

  let fn: () -> ()
}

fileprivate struct ParallelForTask {
  let parallelForFunction: (Int, Int, Int) -> Void  // TODO: convert to not a closure.
  let total: Int
}

fileprivate struct ParallelForTaskSlice {
  let task: UnsafePointer<ParallelForTask>
  let start: Int
  let end: Int
  let grainSize: Int
  var stateStorage = AtomicUInt64()

  mutating func isDoneAcquiring() -> Bool {
    JoinTaskState(stateStorage.valueAcquire).isDone
  }
}

fileprivate struct JoinTask {
  let op: () -> Void
  var stateStorage: AtomicUInt64

  init(_ op: @escaping () -> Void) {
    self.op = op
    stateStorage = AtomicUInt64()
  }

  mutating func isDoneAcquiring() -> Bool {
    JoinTaskState(stateStorage.valueAcquire).isDone
  }
}

fileprivate struct JoinTaskState {
  var underlying: UInt64
  init(_ underlying: UInt64) { self.underlying = underlying }

  var isDone: Bool { underlying & Self.completedMask != 0 }

  func markingDone() -> Self {
    assert(underlying & Self.completedMask == 0)
    return Self(underlying | Self.completedMask)
  }

  var wakeupThread: Int? {
    if underlying & Self.requiresWakeupMask == 0 {
      return nil
    }
    let tid = underlying & Self.wakeupMask
    return tid == Self.externalThreadValue ? -1 : Int(tid)
  }

  func settingWakeupThread(_ threadId: Int) -> Self {
    var tmp = self
    tmp.setWakeupThread(threadId)
    return tmp
  }

  mutating func setWakeupThread(_ threadId: Int) {
    assert(!isDone)
    let tid = threadId == -1 ? Self.externalThreadValue : UInt64(threadId)
    assert(tid & Self.wakeupMask == tid, "\(threadId) -> \(tid) problem")
    underlying |= (tid | Self.requiresWakeupMask)
    assert(
      wakeupThread == threadId,
      "threadId: \(threadId), wakeup thread: \(String(describing: wakeupThread))"
    )
  }

  static let requiresWakeupShift: UInt64 = 32
  static let requiresWakeupMask: UInt64 = 1 << requiresWakeupShift
  static let wakeupMask: UInt64 = requiresWakeupMask - 1
  static let completedShift: UInt64 = requiresWakeupShift + 1
  static let completedMask: UInt64 = 1 << completedShift
  static let externalThreadValue: UInt64 = wakeupMask
}

extension JoinTaskState: CustomStringConvertible {
  public var description: String {
    let wakeupThreadStr: String
    if let wakeupThread = wakeupThread {
      wakeupThreadStr = "\(wakeupThread)"
    } else {
      wakeupThreadStr = "<none>"
    }
    return "JoinTaskState(isDone: \(isDone), wakeupThread: \(wakeupThreadStr)))"
  }
}

fileprivate enum Constants {
  // TODO: convert to runtime parameter? (More spinners reduce latency, but cost extra CPU cycles.)
  static let maxSpinningThreads = 1

  /// The number of steal loop spin interations before parking.
  ///
  /// Note: this number is divided by the number of threads, to get the spin count for each thread.
  static let spinCount = 5000

  /// The minimum number of active threads before thread pool threads are allowed to spin.
  static let minActiveThreadsToStartSpinning = 4
}
