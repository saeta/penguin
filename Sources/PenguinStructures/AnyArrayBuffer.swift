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

extension AnyArrayBuffer where Dispatch == AnyObject {
  /// Creates an instance containing the same elements as `src`.
  public init<Element>(_ src: ArrayBuffer<Element>) {
    self.storage = src.storage.object
    self.dispatch = Void.self as AnyObject
  }

  /// Creates an instance containing the same elements as `src`.
  public init<OtherDispatch>(_ src: AnyArrayBuffer<OtherDispatch>) {
    self.storage = src.storage
    self.dispatch = Void.self as AnyObject
  }
}

extension AnyArrayBuffer {
  /// Creates an instance containing the same elements as `src`, failing if
  /// `src` is not dispatched by a `Dispatch` or a subclass thereof.
  public init?<OtherDispatch>(_ src: AnyArrayBuffer<OtherDispatch>) {
    guard let d = src.dispatch as? Dispatch else { return nil }
    self.storage = src.storage
    self.dispatch = d
  }

  /// Creates an instance containing the same elements as `src`.
  ///
  /// - Requires: `src.dispatch is Dispatch.Type`.
  public init<OtherDispatch>(unsafelyCasting src: AnyArrayBuffer<OtherDispatch>)
  {
    self.storage = src.storage
    self.dispatch = unsafeDowncast(src.dispatch, to: Dispatch.self)
  }
}

/// A type-erased array that is not statically known to support any operations.
public typealias AnyElementArrayBuffer = AnyArrayBuffer<AnyObject>

/// A resizable, value-semantic buffer of homogenous elements of
/// statically-unknown type.
public struct AnyArrayBuffer<Dispatch: AnyObject> {
  public typealias Storage = AnyArrayStorage
  
  /// A bounded contiguous buffer comprising all of `self`'s storage.
  public var storage: Storage?
  /// A “vtable” of functions implementing type-erased operations that depend on the Element type.
  public let dispatch: Dispatch
  
  public init<Element>(storage: ArrayStorage<Element>, dispatch: Dispatch) {
    self.storage = storage.object
    self.dispatch = dispatch
  }
  
  /// Creates a buffer with elements from `src`.
  public init(_ src: AnyArrayBuffer) {
    self.storage = src.storage
    self.dispatch = src.dispatch
  }

  /// Returns `true` iff an element of type `e` can be appended to `self`.
  public func canAppendElement(ofType e: TypeID) -> Bool {
    storage.unsafelyUnwrapped.isUsable(forElementType: e)
  }

  /// Returns the result of invoking `body` on a typed alias of `self`, if
  /// `self.canStoreElement(ofType: Type<Element>.id)`; returns `nil` otherwise.
  public mutating func mutate<Element, R>(
    ifElementType _: Type<Element>,
    _ body: (_ me: inout ArrayBuffer<Element>)->R
  ) -> R? {
    // TODO: check for spurious ARC traffic
    guard var me = ArrayBuffer<Element>(self) else { return nil }
    self.storage = nil
    defer { self.storage = me.storage.object }
    return body(&me)
  }

  /// Returns the result of invoking `body` on a typed alias of `self`.
  ///
  /// - Requires: `self.elementType == Element.self`.
  public mutating func unsafelyMutate<Element, R>(
    assumingElementType _: Type<Element>,
    _ body: (_ me: inout ArrayBuffer<Element>)->R
  ) -> R {
    // TODO: check for spurious ARC traffic
    var me = ArrayBuffer<Element>(unsafelyDowncasting: self)
    self.storage = nil
    defer { self.storage = me.storage.object }
    return body(&me)
  }
}

extension AnyArrayBuffer {
  /// The number of stored elements.
  public var count: Int { storage.unsafelyUnwrapped.count }

  /// The number of elements that can be stored in `self` without reallocation,
  /// provided its representation is not shared with other instances.
  public var capacity: Int { storage.unsafelyUnwrapped.capacity }
}
