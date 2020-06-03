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

// TODO: once some version of atomics lands in Swift, refactor this to make it much nicer!

/// A helper that packs the spinning state of the `NonBlockingThreadPool` into 64 bits.
internal struct NonBlockingSpinningState {
  var underlying: UInt64

  init(_ underlying: UInt64) { self.underlying = underlying }

  /// The number of spinning worker threads.
  var spinningCount: UInt64 {
    get {
      underlying & Self.spinningCountMask
    }
    set {
      assert(newValue < Self.spinningCountMask, "new value: \(newValue)")
      underlying = (underlying & ~Self.spinningCountMask) | newValue
    }
  }

  /// Number of non-notifying submissions into the pool.
  var noNotifyCount: UInt64 {
    (underlying & Self.noNotifyCountMask) >> Self.noNotifyCountShift
  }

  /// True iff a task has been submitted to the pool without notifying the thread pool's `condition`.
  var hasNoNotifyTask: Bool {
    (underlying & Self.noNotifyCountMask) != 0
  }

  /// Returns a new state with the non-notifying count incremented by one.
  func incrementingNoNotifyCount() -> Self {
    Self(underlying + Self.noNotifyCountIncrement)
  }

  /// Decrements the non-notifying count by one.
  mutating func decrementNoNotifyCount() {
    underlying -= Self.noNotifyCountIncrement
  }

  /// Returns a new state with the spinning count incremented by one.
  func incrementingSpinningCount() -> Self {
    Self(underlying + 1)
  }

  /// Returns a new state with the spinning count decremented by one.
  func decrementingSpinningCount() -> Self {
    Self(underlying - 1)
  }

  static let spinningCountBits: UInt64 = 32
  static let spinningCountMask: UInt64 = (1 << spinningCountBits) - 1
  static let noNotifyCountBits: UInt64 = 32
  static let noNotifyCountShift: UInt64 = 32
  static let noNotifyCountMask: UInt64 = ((1 << noNotifyCountBits) - 1) << noNotifyCountShift
  static let noNotifyCountIncrement: UInt64 = (1 << noNotifyCountShift)
}

extension NonBlockingSpinningState: CustomStringConvertible {
  public var description: String {
    "NonblockingSpinningState(spinningCount: \(spinningCount), noNotifyCount: \(noNotifyCount))"
  }
}
