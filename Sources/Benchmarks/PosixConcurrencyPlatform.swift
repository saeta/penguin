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

// -------------------------------------------------------------------------------------------------
// WARNING: temporary duplication of code in PenguinParallel
// (https://github.com/saeta/penguin/issues/114)
// -------------------------------------------------------------------------------------------------

import Foundation
import PenguinStructures

#if os(macOS)
  import Darwin
#elseif os(Windows)
  import ucrt
  import WinSDK
#else
  import Glibc
#endif

internal struct PosixConcurrencyPlatform_: ConcurrencyPlatform, DefaultInitializable {
  internal init() {}
  internal typealias Mutex = NSMutex
  internal typealias ConditionMutex = NSConditionMutex
  internal typealias ConditionVariable = NSConditionVariable
  internal typealias Thread = PosixThread
  internal typealias BaseThreadLocalStorage = PosixThreadLocalStorage

  internal func makeThread(name: String, _ fn: @escaping () -> Void) -> Thread {
    PosixThread(name: name, fn)
  }
}

/// A basic thread implemented on top of POSIX system calls.
internal class PosixThread: ThreadProtocol, CustomStringConvertible {
  // thread handle.
  #if os(Windows)
    typealias Handle = HANDLE
    private var handle: Handle = INVALID_HANDLE_VALUE
  #else
    #if os(macOS)
      typealias Handle = pthread_t?
      private var handle: Handle = nil
    #else
      typealias Handle = pthread_t
      private var handle: Handle = pthread_t()
    #endif
  #endif

  private let name: String

  // Closures aren't explicitly ref-counted, so wrap in a class.
  class BodyHolder {
    /// Initialize `BodyHolder`.
    init(_ body: @escaping () -> Void) { self.body = body }
    /// The body of the thread we should execute.
    let body: () -> Void
  }

  /// Creates a new thread with name `name`.
  init(name: String, _ body: @escaping () -> Void) {
    self.name = name
    let bodyHolder = Unmanaged.passRetained(BodyHolder(body)).toOpaque()
    #if os(Windows)
      fatalError("IMPLEMENT ME!")
    #else  // !os(Windows)
      let status = pthread_create(
        &self.handle,
        nil,
        {
          #if os(macOS)
            let bodyHolder: PosixThread.BodyHolder = Unmanaged.fromOpaque($0).takeRetainedValue()
          #else  // Linux / Android / etc.
            let bodyHolder: PosixThread.BodyHolder = Unmanaged.fromOpaque($0!).takeRetainedValue()
          #endif
          bodyHolder.body()  // Run the thread!
          return nil  // Must return void*
        },
        bodyHolder)
      precondition(status == 0, "Could not pthread_create!")
    #endif
  }

  /// Blocks until the thread represented by `self` terminates.
  internal func join() {
    #if os(Windows)
      fatalError("IMPLEMENT ME!")
    #else
      #if os(macOS)
        precondition(pthread_join(handle!, nil) == 0, "Could not pthread_join")
      #else
        precondition(pthread_join(handle, nil) == 0, "Could not pthread_join")
      #endif
    #endif
  }

  /// A string representation of this thread.
  internal var description: String { "PosixThread(\(name))" }
}

/// A wrapper around `NSLock` to conform to the `MutexProtocol`.
///
/// Note: a wrapper is required in order to satisfy the initialization requirement.
internal struct NSMutex: MutexProtocol, DefaultInitializable {
  private var nsLock = NSLock()

  /// Initializes `self` in an unlocked state.
  internal init() {}

  /// Locks `self`.
  internal func lock() { nsLock.lock() }

  /// Unlocks `self`.
  internal func unlock() { nsLock.unlock() }
}

internal struct NSConditionMutex: ConditionMutexProtocol, DefaultInitializable {
  var condition = NSCondition()
  internal init() {}
  internal func lock() { condition.lock() }
  internal func unlock() {
    condition.signal()
    condition.unlock()
  }
  internal func await(_ predicate: () -> Bool) {
    while !predicate() {
      condition.signal()  // Signal another waiter to potentially wake up.
      condition.wait()
    }
  }
}

internal struct NSConditionVariable: ConditionVariableProtocol, DefaultInitializable {
  internal typealias Mutex = NSMutex

  private var condition = NSCondition()

  /// Initializes an empty condition variable.
  internal init() {}

  internal func wait(_ lock: NSMutex) {
    // Lock priorities: lock > condition.
    condition.lock()
    lock.unlock()
    condition.wait()
    condition.unlock()
    lock.lock()
  }

  internal func signal() {
    // we must lock here before we signal in order to avoid a race condition with waiters.
    condition.lock()
    condition.signal()
    condition.unlock()
  }

  internal func broadcast() {
    condition.lock()
    condition.broadcast()
    condition.unlock()
  }
}
