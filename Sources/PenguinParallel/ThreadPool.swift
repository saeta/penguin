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
	/// Schedules `fn` to be executed in the threadpool eventually.
	func dispatch(_ fn: @escaping () -> Void)

	/// Executes `a` and `b` optionally in parallel; both are guaranteed to have finished executing
	/// before `join` returns.
	func join(_ a: () -> Void, _ b: () -> Void)

	/// The maximum amount of parallelism possible within this thread pool.
	var parallelism: Int { get }
}

/// Typed compute threadpools support additional sophisticated operations.
public protocol TypedComputeThreadPool: ComputeThreadPool {
    /// Submit a task to be executed on the threadpool.
    ///
    /// `pRun` will execute task in parallel on the threadpool and it will complete at a future time.
    /// `pRun` returns immediately.
    func dispatch(_ task: (Self) -> Void)

    /// Run two tasks (optionally) in parallel.
    ///
    /// Fork-join parallelism allows for efficient work-stealing parallelism. The two non-escaping
    /// functions will have finished executing before `pJoin` returns. The first function will execute on
    /// the local thread immediately, and the second function will execute on another thread if resources
    /// are available, or on the local thread if there are not available other resources.
    func join(_ a: (Self) -> Void, _ b: (Self) -> Void)
}

extension TypedComputeThreadPool {
	public func dispatch(_ fn: @escaping () -> Void) {
		dispatch { _ in fn() }
	}

	public func join(_ a: () -> Void, _ b: () -> Void) {
		join({ _ in a() }, { _ in b() })
	}
}

/// A namespace for threadpool operations.
public enum ComputeThreadPools {}

// extension ComputeThreadPools {
// 	static var global: ComputeThreadPool
// }
