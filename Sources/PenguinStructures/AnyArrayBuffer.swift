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
public struct AnyArrayBuffer<Storage: AnyArrayStorage> {
  /// A bounded contiguous buffer comprising all of `self`'s storage.
  ///
  /// Note: `storage` has reference semantics. Clients that mutate the `storage` must take care to
  /// preserve `ArrayBuffer`'s value semantics by ensuring that `storage` is uniquely referenced.
  public var storage: Storage
  
  init(storage: Storage) { self.storage = storage }
  
  public init<SrcStorage>(_ src: ArrayBuffer<SrcStorage>) {
    // The downcast would be unnecessary but for
    // https://bugs.swift.org/browse/SR-12906
    self.storage = unsafeDowncast(src.storage, to: Storage.self)
  }

  /// Creates a buffer with elements from `src`.
  ///
  /// Precondition: `SrcStorage: Storage` (we could express this in the
  /// signature but for https://bugs.swift.org/browse/SR-12906).
  public init<SrcStorage>(_ src: AnyArrayBuffer<SrcStorage>) {
    self.storage = unsafeDowncast(src.storage, to: Storage.self)
  }

  /// Returns a buffer with elements from `self`, and storage type
  /// `DesiredStorage`, if `Self.Storage` can be cast to `DesiredStorage`.
  public func cast<DesiredStorage>(to _: DesiredStorage.Type)
    -> AnyArrayBuffer<DesiredStorage>?
  {
    guard let desiredStorage = storage as? DesiredStorage else { return nil }
    return AnyArrayBuffer<DesiredStorage>(storage: desiredStorage)
  }

  /// The type of element stored here.
  public var elementType: Any.Type { storage.elementType }

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

  /// Returns the result of calling `body` on the elements of `self`.
  public func withUnsafeRawPointerToElements<R>(
    body: (UnsafeRawPointer)->R
  ) -> R {
    storage.withUnsafeMutableRawBufferPointer { b in
      body(b.baseAddress.map { .init($0) } ?? UnsafeRawPointer(bitPattern: -1).unsafelyUnwrapped)
    }
  }

  /// Returns the result of calling `body` on the elements of `self`.
  public mutating func withUnsafeMutableRawPointerToElements<R>(
    _ body: (inout UnsafeMutableRawPointer)->R
  ) -> R {
    ensureUniqueStorage()
    return storage.withUnsafeMutableRawBufferPointer { b in
      var ba = b.baseAddress ?? UnsafeMutableRawPointer(bitPattern: -1).unsafelyUnwrapped
      return body(&ba)
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
