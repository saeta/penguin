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

/// A value-semantic collection of `Storage.Element` with unbounded growth.
public struct ArrayBuffer<Storage: ArrayStorageImplementation> {
  public typealias Element = Storage.Element

  /// A bounded contiguous buffer comprising all of `self`'s storage.
  ///
  /// Note: `storage` has reference semantics. Clients that mutate the `storage`
  /// must take care to preserve `ArrayBuffer`'s value semantics by ensuring
  /// that `storage` is uniquely referenced.
  public var storage: Storage

  /// The number of stored elements.
  public var count: Int { storage.count }

  /// The number of elements that can be stored in `self` without reallocation,
  /// provided its representation is not shared with other instances.
  public var capacity: Int { storage.capacity }

  /// Creates an instance with capacity of at least `minimumCapacity`.
  public init(minimumCapacity: Int = 0) {
    storage = Storage(minimumCapacity: minimumCapacity)
  }

  /// Creates an instance with the same elements as `contents`, having a
  /// `capacity` of at least `minimumCapacity`.
  public init<Contents: Collection>(
    _ contents: Contents, minimumCapacity: Int = 0
  )
    where Contents.Element == Element
  {
    storage = .init(contents, minimumCapacity: minimumCapacity)
  }
  
  /// Appends `x`, returning the index of the appended element.
  ///
  /// - Complexity: Amortized O(1).
  public mutating func append(_ x: Element) -> Int {
    let isUnique = isKnownUniquelyReferenced(&storage)
    if isUnique, let r = storage.append(x) { return r }
    storage = storage.appending(x, moveElements: isUnique)
    return count - 1
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
    ensureUniqueStorage()
    return storage.withUnsafeMutableBufferPointer(body)
  }

  /// Ensure that we hold uniquely-referenced storage.
  public mutating func ensureUniqueStorage() {
    guard !isKnownUniquelyReferenced(&storage) else { return }
    storage = storage.makeCopy()
  }
}

extension ArrayBuffer: RandomAccessCollection, MutableCollection {
  /// A position in the buffer.
  public typealias Index = Int
  
  /// The position of the first element.
  public var startIndex: Int { 0 }
  
  /// The position just past the last element.
  public var endIndex: Int { count }
  
  /// Accesses the element at `i`.
  ///
  /// - Requires: `i >= 0 && i < count`.
  /// - Note: this is not a memory-safe API; if `i` is out-of-range, the
  ///   behavior is undefined.
  public subscript(_ i: Index) -> Element {
    get { storage[i] }
    _modify {
      if isKnownUniquelyReferenced(&storage) { yield &storage[i] } 
      else {
        storage = storage.makeCopy()
        yield &storage[i]
      }
    }
  }
}
