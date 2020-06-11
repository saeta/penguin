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

  /// The type of element stored here.
  public var elementType: Any.Type { storage.elementType }

  /// Returns the result of calling `body` on the elements of `self`.
  ///
  /// - Requires: `elementType == T.self``
  public func withUnsafeBufferPointer<T, R>(
    assumingElementType _: T.Type,
    _ body: (UnsafeBufferPointer<T>)->R
  ) -> R {
    storage.withUnsafeMutableBufferPointer(assumingElementType: T.self) {
      body(.init($0))
    }
  }

  /// Returns the result of calling `body` on the elements of `self`.
  ///
  /// - Requires: `elementType == T.self``
  public mutating func withUnsafeMutableBufferPointer<T, R>(
    assumingElementType _: T.Type,
    _ body: (inout UnsafeMutableBufferPointer<T>)->R
  ) -> R {
    ensureUniqueStorage()
    return storage.withUnsafeMutableBufferPointer(assumingElementType: T.self, body)
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
  public mutating func append<T>(_ x: T) -> Int {
    assert(type(of: x) == elementType)
    let isUnique = isKnownUniquelyReferenced(&storage)
    return withUnsafePointer(to: x) {
      if isUnique, let r = storage.appendValue(at: .init($0)) { return r }
      storage = storage.appendingValue(at: .init($0), moveElements: isUnique)
      return count - 1
    }
  }
}
