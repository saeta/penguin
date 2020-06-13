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

  /// A piece of storage that can be swapped into an instance of `Self` while it
  /// is being mutated as an `ArrayBuffer` of statically known element type, to
  /// preserve uniqueness.
  private static let dummyStorage: AnyArrayStorage = ArrayStorage<()>()

  /// Returns the result of invoking `body` on a typed alias of `self`, if
  /// `self.elementType == Element.self`; returns `nil` otherwise.
  public mutating func mutate<Element, R>(
    ifElementType _: Element.Type,
    _ body: (_ me: inout ArrayBuffer<Element>)->R
  ) -> R? {
    // TODO: check for spurious ARC traffic
    guard var me = ArrayBuffer<Element>(self) else { return nil }
    self.storage = Self.dummyStorage
    defer { self.storage = me.storage }
    return body(&me)
  }

  /// Returns the result of invoking `body` on a typed alias of `self`.
  ///
  /// - Requires: `self.elementType == Element.self`.
  public mutating func unsafelyMutate<Element, R>(
    assumingElementType _: Element.Type,
    _ body: (_ me: inout ArrayBuffer<Element>)->R
  ) -> R {
    // TODO: check for spurious ARC traffic
    var me = ArrayBuffer<Element>(unsafelyDowncasting: self)
    self.storage = Self.dummyStorage
    defer { self.storage = me.storage }
    return body(&me)
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
}
