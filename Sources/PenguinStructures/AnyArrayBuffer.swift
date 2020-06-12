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

/// A resizable, value-semantic buffer of homogenous elements of
/// statically-unknown type.
public struct AnyArrayBuffer {
  public typealias Storage = AnyArrayStorage
  
  /// A bounded contiguous buffer comprising all of `self`'s storage.
  ///
  /// Note: `storage` has reference semantics. Clients that mutate the `storage` must take care to
  /// preserve `ArrayBuffer`'s value semantics by ensuring that `storage` is uniquely referenced.
  public var storage: Storage
  
  init(storage: Storage) { self.storage = storage }
  
  public init<Element>(_ src: ArrayBuffer<Element>) {
    self.storage = unsafeDowncast(src.storage, to: Storage.self)
  }

  /// Creates a buffer with elements from `src`.
  public init(_ src: AnyArrayBuffer) {
    self.storage = src.storage
  }

  /// The type of element stored here.
  public var elementType: Any.Type { type(of: storage).elementType }

  /// Returns the result of calling `body` on the elements of `self`.
  ///
  /// - Requires: `elementType == Element.self``
  public func withUnsafeBufferPointer<Element, R>(
    assumingElementType _: Element.Type,
    _ body: (UnsafeBufferPointer<Element>)->R
  ) -> R {
    storage.withUnsafeMutableBufferPointer(assumingElementType: Element.self) {
      body(.init($0))
    }
  }

  /// Returns the result of calling `body` on the elements of `self`.
  ///
  /// - Requires: `elementType == Element.self``
  public mutating func withUnsafeMutableBufferPointer<Element, R>(
    assumingElementType _: Element.Type,
    _ body: (inout UnsafeMutableBufferPointer<Element>)->R
  ) -> R {
    ensureUniqueStorage()
    return storage.withUnsafeMutableBufferPointer(
      assumingElementType: Element.self, body)
  }

  /// Accesses the `i`th element.
  ///
  /// - Requires: `elementType == Element.self``
  public subscript<Element>(
    i: Int,
    assumingElementType _: Element.Type = Element.self
  ) -> Element {
    _read {
      yield withUnsafeBufferPointer(assumingElementType: Element.self) { $0[i] }
    }
    _modify {
      defer { _fixLifetime(self) }
      yield &withUnsafeMutableBufferPointer(
        assumingElementType: Element.self) { $0 }[i]
    }
  }

  /// Ensure that we hold uniquely-referenced storage.
  public mutating func ensureUniqueStorage() {
    guard !isKnownUniquelyReferenced(&storage) else { return }
    storage = storage.makeCopy()
  }
}

extension AnyArrayBuffer {
  /// The number of stored elements.
  public var count: Int { storage.count }

  /// The number of elements that can be stored in `self` without reallocation,
  /// provided its representation is not shared with other instances.
  public var capacity: Int { storage.capacity }

  /// Appends `x`, returning the index of the appended element.
  ///
  /// - Complexity: Amortized O(1).
  /// - Precondition: `type(of: x) == elementType`
  public mutating func append<Element>(_ x: Element) -> Int {
    let isUnique = isKnownUniquelyReferenced(&storage)
    if isUnique, let r = storage.unsafelyAppend(x) { return r }
    storage = storage.unsafelyAppending(x, moveElements: isUnique)
    return count - 1
  }
}
