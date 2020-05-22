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

/// Allows efficient use of multi-core CPUs by managing a fixed-size collection of threads.
///
/// From first-principles, a (CPU) compute-bound application will run at peak performance when
/// overheads are minimized. Once enough parallelism is exposed to leverage all cores, one of the
/// key overheads to minimize is context switching, and thead creation / destruction. The optimal
/// system configuration is thus a fixed-size threadpool where there is exactly one thread per CPU
/// core (or rather, hyperthread). This configuration results in zero context switching, no
/// additional kernel calls for thread creation & deletion, and full utilization of the hardware.
///
/// Unfortunately, in practice, it is infeasible to statically schedule work apriori onto a fixed
/// pool of threads. Even when applying the same operation to a homogenous dataset, there will
/// inevitably be variability in execution time. (This can arise from I/O interrupts taking over a
/// core [briefly], or page faults, or even different latencies for memory access across NUMA
/// domains.) As a result, it is important for peak performance to build abstractions that are
/// flexible and dynamic in their work allocation.
///
/// The `ComputeThreadPool` protocol is a foundational API designed to enable efficient use of
/// hardware resources. There are two APIs exposed to support two kinds of parallelism. For
/// additional details, please see the documentation associated with each.
///
/// Note: be sure to avoid executing code on the `ComputeThreadPool` that is not compute-bound. If
/// you are doing I/O, be sure to use a dedicated threadpool, or use
/// [Swift NIO](https://github.com/apple/swift-nio) for high performance non-blocking I/O.
///
/// Note: while there should be only one "physical" threadpool process-wide, there can be many
/// virtual threadpools that compose on top of this one to allow configuration and tuning. (This is
/// why `ComputeThreadPool` is a protocol and not static methods.) Examples of additional threadpool
/// abstractions could include a separate threadpool per-NUMA domain, to support different
/// priorities for tasks, or higher-level parallelism primitives such as "wait-groups".
///
/// - SeeAlso: `ComputeThreadPools`
public protocol ComputeThreadPool {
  // TODO: should the methods be marked as mutating?

  /// Schedules `fn` to be executed in the threadpool eventually.
  func dispatch(_ fn: @escaping () -> Void)

  /// Executes `a` and `b` optionally in parallel; both are guaranteed to have finished executing
  /// before `join` returns.
  func join(_ a: () -> Void, _ b: () -> Void)

  /// Executes `a` and `b` optionally in parallel; if one throws, it is unspecified whether the
  /// other will have started or completed executing. It is also unspecified as to which error
  /// will be thrown.
  ///
  /// This is the throwing overload
  func join(_ a: () throws -> Void, _ b: () throws -> Void) throws

  /// A function that can be executed in parallel.
  ///
  /// The first argument is the index of the invocation, and the second argument is the total number
  /// of invocations.
  typealias ParallelForFunction = (Int, Int) -> Void

  /// A function that can be executed in parallel.
  ///
  /// The first argument is the index of the copy, and the second argument is the total number of
  /// copies being executed.
  typealias ThrowingParallelForFunction = (Int, Int) throws -> Void

  /// A vectorized function that can be executed in parallel.
  ///
  /// The first argument is the start index for the vectorized operation, and the second argument
  /// corresponds to the end of the range. The third argument contains the total size of the range.
  typealias VectorizedParallelForFunction = (Int, Int, Int) -> Void

  /// A vectorized function that can be executed in parallel.
  ///
  /// The first argument is the start index for the vectorized operation, and the second argument
  /// corresponds to the end of the range. The third argument contains the total size of the range.
  typealias ThrowingVectorizedParallelForFunction = (Int, Int, Int) throws -> Void

  /// Returns after executing `fn` `n` times.
  ///
  /// - Parameter n: The total times to execute `fn`.
  func parallelFor(n: Int, _ fn: ParallelForFunction)

  /// Returns after executing `fn` an unspecified number of times, guaranteeing that `fn` has been
  /// called with parameters that perfectly cover of the range `0..<n`.
  ///
  /// - Parameter n: The range of numbers `0..<n` to cover.
  func parallelFor(n: Int, _ fn: VectorizedParallelForFunction)

  /// Returns after executing `fn` `n` times.
  ///
  /// - Parameter n: The total times to execute `fn`.
  func parallelFor(n: Int, _ fn: ThrowingParallelForFunction) throws

  /// Returns after executing `fn` an unspecified number of times, guaranteeing that `fn` has been
  /// called with parameters that perfectly cover of the range `0..<n`.
  ///
  /// - Parameter n: The range of numbers `0..<n` to cover.
  func parallelFor(n: Int, _ fn: ThrowingVectorizedParallelForFunction) throws


  // TODO: Add this & a default implementation!
  // /// Returns after executing `fn` `n` times.
  // ///
  // /// - Parameter n: The total times to execute `fn`.
  // /// - Parameter blocksPerThread: The minimum block size to subdivide. If unspecified, a good
  // ///   value will be chosen based on the amount of available parallelism.
  // func parallelFor(blockingUpTo n: Int, blocksPerThread: Int, _ fn: ParallelForFunction)
  // func parallelFor(blockingUpTo n: Int, _ fn: ParallelForFunction)

  /// The maximum amount of parallelism possible within this thread pool.
  var parallelism: Int { get }

  /// Returns the index of the current thread in the pool, if running on a thread-pool thread,
  /// nil otherwise.
  ///
  /// The return value is guaranteed to be either nil, or between 0 and `parallelism`.
  var currentThreadIndex: Int? { get }
}

extension ComputeThreadPool {

  /// Convert a non-vectorized operation to a vectorized operation.
  public func parallelFor(n: Int, _ fn: ParallelForFunction) {
    parallelFor(n: n) { start, end, total in
      for i in start..<end {
        fn(i, total)
      }
    }
  }

  /// Convert a non-vectorized operation to a vectorized operation.
  public func parallelFor(n: Int, _ fn: ThrowingParallelForFunction) throws {
    try parallelFor(n: n) { start, end, total in
      for i in start..<end {
        try fn(i, total)
      }
    }
  }
}

/// A `ComputeThreadPool` that executes everything immediately on the current thread.
///
/// This threadpool implementation is useful for testing correctness, as well as avoiding context
/// switches when a computation is designed to be parallelized at a coarser level.
public struct InlineComputeThreadPool: ComputeThreadPool {
  /// Initializes `self`.
  public init() {}

  /// The amount of parallelism available in this thread pool.
  public var parallelism: Int { 1 }

  /// The index of the current thread.
  public var currentThreadIndex: Int? { 0 }

  /// Dispatch `fn` to be run at some point in the future (immediately).
  ///
  /// Note: this implementation just executes `fn` immediately.
  public func dispatch(_ fn: () -> Void) {
    fn()
  }

  /// Executes `a` and `b` optionally in parallel, and returns when both are complete.
  ///
  /// Note: this implementation simply executes them serially.
  public func join(_ a: () -> Void, _ b: () -> Void) {
    a()
    b()
  }

  /// Executes `a` and `b` optionally in parallel, and returns when both are complete.
  ///
  /// Note: this implementation simply executes them serially.
  public func join(_ a: () throws -> Void, _ b: () throws -> Void) throws {
    try a()
    try b()
  }

  public func parallelFor(n: Int, _ fn: VectorizedParallelForFunction) {
    fn(0, n, n)
  }

  public func parallelFor(n: Int, _ fn: ThrowingVectorizedParallelForFunction) throws {
    try fn(0, n, n)
  }
}

/// A namespace for threadpool operations.
public enum ComputeThreadPools {}

extension ComputeThreadPools {
  /// A global default `ComputeThreadPool`.
  ///
  /// When you need a `ComputeThreadPool` use the `local` `ComputeThreadPool`, as this allows
  /// parts of the app to configure a customized `ComputeThreadPool`. `global` is used when the
  /// `local` thread pool hasn't yet been set. (In particular, the global thread pool is copied
  /// into the thread-local storage upon first access.)
  ///
  /// `global` is made public so that early upon a process start-up (before any references to
  /// `local` are made), code can cofigure a customized `global` thread pool.
  ///
  /// - SeeAlso: `local`
  public static var global: ComputeThreadPool = InlineComputeThreadPool()  // TODO: switch me!

  /// Typed  thread local storage.
  private typealias TLS = TypedThreadLocalStorage<PosixThreadLocalStorage>

  /// A AnyObject type to hold onto a `ComputeThreadPool` inside thread local storage.
  private class ThreadPoolHolder {
    var pool: ComputeThreadPool
    init(pool: ComputeThreadPool) {
      self.pool = pool
    }
  }
  /// A key used to index into the thread local storage.
  private static let threadLocalKey = TLS.makeKey(for: ThreadPoolHolder.self)

  /// A thread local `ComputeThreadPool`.
  ///
  /// Use this thread pool whenever you need a thread pool in your applications and have not been
  /// provided one by the caller. (Rationale: by using a thread-local instead of a global, regions
  /// of code can be easily configured to use a given `ComputeThreadPool`).
  public static var local: ComputeThreadPool {
    get {
      TLS.get(threadLocalKey, default: ThreadPoolHolder(pool: global)).pool
    }
    set {
      if let holder = TLS.get(threadLocalKey) {
        holder.pool = newValue
      } else {
        TLS.set(ThreadPoolHolder(pool: newValue), for: threadLocalKey)
      }
    }
  }

  /// The thread index for the current thread, based on the current thread-local compute pool.
  public static var currentThreadIndex: Int? {
    local.currentThreadIndex
  }

  /// The amount of parallelism provided by the current thread-local compute pool.
  public static var parallelism: Int {
    local.parallelism
  }

  /// Sets `pool` to `local` for the duration of `body`.
  public static func withPool<T>(_ pool: ComputeThreadPool, _ body: () throws -> T) rethrows -> T {
    var tmp = pool
    swap(&tmp, &local)
    defer { swap(&tmp, &local) }
    return try body()
  }
}
