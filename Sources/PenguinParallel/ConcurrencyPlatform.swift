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

/// Abstracts over different concurrency abstractions.
///
/// Some environments have different concurrency abstractions, such as fundamental locks, threads
/// and condition variables. This protocol allows writing code that is generic across the different
/// concurrency environments.
///
/// These abstractions are designed to be relatively minimialistic in order to be easy to port to a
/// variety of environments. Key environments include: macOS, Linux, Android, Windows, and Google's
/// internal enviornment.
public protocol ConcurrencyPlatform {
	/// The type of mutexes (aka locks) used.
	associatedtype Mutex // : MutexProtocol  // Commented out due to redundant conformance warning.
	/// The type of conditional mutexes that are available.
	associatedtype ConditionMutex: ConditionMutexProtocol
	/// The type of the condition variable that's available.
	associatedtype ConditionVariable: ConditionVariableProtocol where ConditionVariable.Mutex == Mutex
	/// The type of threads that are used.
	associatedtype Thread: ThreadProtocol

	/// Makes a thread.
	func makeThread(name: String, _ fn: @escaping () -> Void) -> Thread

	// TODO: Add a thread-local abstraction!
}

/// Represents a thread of execution.
public protocol ThreadProtocol {
	/// Blocks until the thread has finished executing.
	///
	/// If `self` has already finished executing, `join()` returns immediately. It is up to the
	/// application to signal to the executing thread that it should exit if it will not do so
	/// otherwise.
	///
	/// This function can be called multiple times.
	func join()
}

/// Mutual exclusion locks.
public protocol MutexProtocol {
	// TODO: determine if `lock` and `unlock` should be mutating methods.

	/// Initializes the lock in the unlocked state.
	init()

	/// Locks the lock
	func lock()

	/// Unlocks the lock.
	func unlock()
}

extension MutexProtocol {
	/// Runs `fn` while holding `self`'s lock.
	public func withLock<T>(_ fn: () throws -> T) rethrows -> T {
		lock()
		defer { unlock() }
		return try fn()
	}
}

/// Allows for waiting until a given condition is satisifed.
public protocol ConditionMutexProtocol: MutexProtocol {

	/// Locks `self` when `predicate` returns true.
	///
	/// Must be called when `self` is not locked by the current thread of execution.
	///
	/// - Parameter predicate: A function that returns `true` when the lock should be locked by the
	///   current thread of execution. `predicate` is only executed while holding the lock.
	func lockWhen(_ predicate: () -> Bool)

	func lockWhen<T>(_ predicate: () -> Bool, _ body: () throws -> T) rethrows -> T

	/// Unlocks `self` until `predicate` returns `true`.
	///
	/// Must be called when `self` is locked by the current thread of execution.
	///
	/// - Parameter predicate: A function that returns `true` when `self` should be locked by the
	///   current thread of execution. `predicate` is only executed while holding the lock.
	func await(_ predicate: () -> Bool)
}

extension ConditionMutexProtocol {
	public func lockWhen(_ predicate: () -> Bool) {
		lock()
		await(predicate)
	}

	public func lockWhen<T>(_ predicate: () -> Bool, _ body: () throws -> T) rethrows -> T {
		lockWhen(predicate)
		defer { unlock() }
		return try body()
	}
}

/// A condition variable.
///
/// Only perform operations on `self` when holding the mutex associated with `self`.
public protocol ConditionVariableProtocol {
	/// The mutex type associated with this condition variable.
	associatedtype Mutex: MutexProtocol

	/// Initializes `self`.
	init()

	/// Wait until signaled, releasing `lock` while waiting.
	///
	/// - Precondition: `lock` is locked.
	/// - Postcondition: `lock` is locked.
	func wait(_ lock: Mutex)

	/// Wake up one waiter.
	///
	/// - Precondition: the `lock` associated with `self` is locked.
	func signal()

	/// Wake up all waiters.
	///
	/// - Precondition: the `lock` associated with `self` is locked.
	func broadcast()
}
