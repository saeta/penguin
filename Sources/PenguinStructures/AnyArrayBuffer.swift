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

public typealias AnyArrayBuffer = AnyArrayBuffer_<AnyArrayDispatch_>
public final class AnyArrayDispatch_ {}

extension AnyArrayBuffer {
  public init<Element>(_ src: ArrayBuffer<Element>) {
    self.storage = src.storage
    self.dispatch = AnyArrayDispatch_.self
  }
}

/// A resizable, value-semantic buffer of homogenous elements of
/// statically-unknown type.
public struct AnyArrayBuffer_<Dispatch: AnyObject> {
  public typealias Storage = AnyArrayStorage
  
  /// A bounded contiguous buffer comprising all of `self`'s storage.
  public var storage: Storage?
  public let dispatch: Dispatch.Type
  
  public init(storage: Storage, dispatch: Dispatch.Type) {
    self.storage = storage
    self.dispatch = dispatch
  }
  
  /// Creates a buffer with elements from `src`.
  public init(_ src: AnyArrayBuffer_) {
    self.storage = src.storage
    self.dispatch = src.dispatch
  }

  /// The type of element stored here.
  public var elementType: Any.Type { storage?.elementType ?? Never.self }

  /// Returns the result of invoking `body` on a typed alias of `self`, if
  /// `self.elementType == Element.self`; returns `nil` otherwise.
  public mutating func mutate<Element, R>(
    ifElementType _: Element.Type,
    _ body: (_ me: inout ArrayBuffer<Element>)->R
  ) -> R? {
    // TODO: check for spurious ARC traffic
    guard var me = ArrayBuffer<Element>(self) else { return nil }
    self.storage = nil
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
    self.storage = nil
    defer { self.storage = me.storage }
    return body(&me)
  }

  /// Ensure that we hold uniquely-referenced storage.
  public mutating func ensureUniqueStorage() {
    guard !isKnownUniquelyReferenced(&storage) else { return }
    storage = storage.unsafelyUnwrapped.makeCopy()
  }
}

extension AnyArrayBuffer_ {
  /// The number of stored elements.
  public var count: Int { storage.unsafelyUnwrapped.count }

  /// The number of elements that can be stored in `self` without reallocation,
  /// provided its representation is not shared with other instances.
  public var capacity: Int { storage.unsafelyUnwrapped.capacity }
}
