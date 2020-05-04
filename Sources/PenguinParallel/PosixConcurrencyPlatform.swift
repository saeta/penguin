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

public struct PosixConcurrencyPlatform: ConcurrencyPlatform, DefaultInitializable {
  public init() {}
  public typealias Mutex = NSMutex
  public typealias ConditionMutex = NSConditionMutex
  public typealias ConditionVariable = NSConditionVariable
  public typealias Thread = PosixThread
  public typealias BaseThreadLocalStorage = PosixThreadLocalStorage

  public func makeThread(name: String, _ fn: @escaping () -> Void) -> Thread {
    PosixThread(name: name, fn)
  }
}

/// A basic thread implemented on top of POSIX system calls.
public class PosixThread: ThreadProtocol, CustomStringConvertible {
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
  public func join() {
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
  public var description: String { "PosixThread(\(name))" }
}

/// A wrapper around `NSLock` to conform to the `MutexProtocol`.
///
/// Note: a wrapper is required in order to satisfy the initialization requirement.
public struct NSMutex: MutexProtocol, DefaultInitializable {
  private var nsLock = NSLock()

  /// Initializes `self` in an unlocked state.
  public init() {}

  /// Locks `self`.
  public func lock() { nsLock.lock() }

  /// Unlocks `self`.
  public func unlock() { nsLock.unlock() }
}

public struct NSConditionMutex: ConditionMutexProtocol, DefaultInitializable {
  var condition = NSCondition()
  public init() {}
  public func lock() { condition.lock() }
  public func unlock() {
    condition.signal()
    condition.unlock()
  }
  public func await(_ predicate: () -> Bool) {
    while !predicate() {
      condition.signal()  // Signal another waiter to potentially wake up.
      condition.wait()
    }
  }
}

public struct NSConditionVariable: ConditionVariableProtocol {
  public typealias Mutex = NSMutex

  private var condition = NSCondition()

  /// Initializes an empty condition variable.
  public init() {}

  public func wait(_ lock: NSMutex) {
    // Lock priorities: lock > condition.
    condition.lock()
    lock.unlock()
    condition.wait()
    condition.unlock()
    lock.lock()
  }

  public func signal() {
    // we must lock here before we signal in order to avoid a race condition with waiters.
    condition.lock()
    condition.signal()
    condition.unlock()
  }

  public func broadcast() {
    condition.lock()
    condition.broadcast()
    condition.unlock()
  }
}

public struct PosixThreadLocalStorage: RawThreadLocalStorage {
  #if os(macOS)
    /// A function to delete the raw memory.
    typealias KeyDestructor = @convention(c) (UnsafeMutableRawPointer) -> Void
    private static let keyDestructor: KeyDestructor = {
      Unmanaged<AnyObject>.fromOpaque($0).release()
    }
  #else
    /// A function to delete the raw memory.
    typealias KeyDestructor = @convention(c) (UnsafeMutableRawPointer?) -> Void
    private static let keyDestructor: KeyDestructor = {
      if let obj = $0 {
        Unmanaged<AnyObject>.fromOpaque(obj).release()
      }
    }
  #endif

  public struct Key {
    #if os(Windows)
      var value: DWORD
    #else
      var value: pthread_key_t
    #endif

    init() {
      #if os(Windows)
        fatalError("Unimplemented!")
      #else
        value = pthread_key_t()
        pthread_key_create(&value, keyDestructor)
      #endif
    }
  }

  public static func makeKey() -> Key {
    Key()
  }

  public static func get(for key: Key) -> UnsafeMutableRawPointer? {
    pthread_getspecific(key.value)
  }

  public static func set(value: UnsafeMutableRawPointer?, for key: Key) {
    pthread_setspecific(key.value, value)
  }
}
