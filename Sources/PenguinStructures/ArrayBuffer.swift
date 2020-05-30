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

/// A resizable, value-semantic collection of `T` that can be type-erased to
/// `AnyArrayStorage`.
public struct ArrayBuffer<Storage: ArrayStorageImplementation> {
  public typealias Element = Storage.Element

  /// A bounded contiguous buffer comprising all of `self`'s storage.
  private var storage: Storage

  /// The number of stored elements.
  public var count: Int { storage.count }

  /// The number of elements that can be stored in `self` without reallocation,
  /// provided its representation is not shared with other instances.
  public var capacity: Int { storage.capacity }

  /// Creates an instance with capacity of at least `minimumCapacity`.
  public init(minimumCapacity: Int = 0) {
    storage = Storage.create(minimumCapacity: minimumCapacity)
  }

  /// Appends `x`, returning the index of the appended element.
  ///
  /// - Complexity: Amortized O(1).
  public mutating func append(_ x: Element) -> Int {
    let isUnique = isKnownUniquelyReferenced(&storage)
    if isUnique, let r = storage.append(x) { return r }
    
    return appendSlowPath(x, moveElements: isUnique)
  }

  /// Replaces the storage of `self` with new storage having at least the given
  /// capacity, calling `initialize` with pointers to the old and new storage
  /// base addresses, and writing the result into `count`.
  private mutating func replaceStorage(
    newCount: Int,
    minimumCapacity: Int,
    initialize: (
      UnsafeMutablePointer<Element>, UnsafeMutablePointer<Element>) -> Void
  ) {
    assert(minimumCapacity >= newCount)
    let newStorage = Storage.create(minimumCapacity: minimumCapacity)
    newStorage.count = newCount
    
    storage.withUnsafeMutableBufferPointer { src in
      newStorage.withUnsafeMutableBufferPointer { dst in
        initialize(
          src.baseAddress.unsafelyUnwrapped,
          dst.baseAddress.unsafelyUnwrapped)
      }
    }
    storage = newStorage
  }
  
  /// Creates new underlying storage containing the contents of `self` followed
  /// by `x`, moving elements from the existing storage iff `moveElements` is
  /// true.
  ///
  /// - Postcondition: if `count == capacity` on invocation, `capacity` is
  ///   scaled up by a constant factor.
  ///
  /// - Complexity: O(N).
  @inline(never)
  private mutating func appendSlowPath(_ x: Element, moveElements: Bool) -> Int {
    let oldCount = self.count
    let oldCapacity = self.capacity
    let newCount = oldCount + 1
    let minCapacity = oldCount < oldCapacity ? oldCapacity
      : max(newCount, 2 * oldCount)
    
    if moveElements { storage.count = 0 }
    replaceStorage(
      newCount: newCount, minimumCapacity: minCapacity
    ) { src, dst in
      if moveElements { dst.moveInitialize(from: src, count: oldCount) }
      else { dst.initialize(from: src, count: oldCount) }
      (dst + oldCount).initialize(to: x)
    }
    return oldCount
  }

  /// Returns the result of calling `body` on the elements of `self`.
  public func withUnsafeBufferPointer<R>(
    body: (UnsafeBufferPointer<Element>)->R
  ) -> R {
    storage.withUnsafeMutableBufferPointer { b in body(.init(b)) }
  }

  /// Returns the result of calling `body` on the elements of `self`.
  public mutating func withUnsafeMutableBufferPointer<R>(
    _ body: (inout UnsafeMutableBufferPointer<Element>)->R
  ) -> R {
    isKnownUniquelyReferenced(&storage)
      ? storage.withUnsafeMutableBufferPointer(body)
      : withUnsafeMutableBufferPointerSlowPath(body)
  }

  /// Returns the result of calling `body` on the elements of `self`, after
  /// replacing the underlying storage with a uniquely-referenced copy.
  @inline(never)
  private mutating func withUnsafeMutableBufferPointerSlowPath<R>(
    _ body: (inout UnsafeMutableBufferPointer<Element>)->R
  ) -> R {
    replaceStorage(newCount: count, minimumCapacity: capacity) {
      [count] src, dst in
      dst.initialize(from: src, count: count)
    }
    return storage.withUnsafeMutableBufferPointer(body)
  }
}


