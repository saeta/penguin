//******************************************************************************
// Copyright 2020 Penguin Authors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//    https://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//

//******************************************************************************
// This file exposes reference-counted buffer types similar to the storage for
// `Array`, but designed to be (potentially) handled through type-erased APIs
// that are statically `Element`-type-agnostic.
//******************************************************************************

/// Effectively, the stored properties of every `ArrayStorage` instance.
fileprivate struct ArrayHeader {
  var count: Int
  var capacity: Int
}

extension FactoryInitializable where Self: AnyArrayStorage {
  /// A way to access the storage when the element type is known
  fileprivate typealias Accessor_<Element>
    = ManagedBufferPointer<ArrayHeader, Element>

  /// Returns new storage having at least the given capacity, calling
  /// `initialize` with pointers to the base addresses of self and the new
  /// storage.
  ///
  /// - Requires: `Element.self == elementType`
  public func replacementStorage<Element>(
    assumingElementType _: Element.Type,
    count newCount: Int,
    minimumCapacity: Int,
    initialize: (
      _ selfBase: UnsafeMutablePointer<Element>,
      _ replacementBase: UnsafeMutablePointer<Element>) -> Void
  ) -> Self {
    assert(minimumCapacity >= newCount)
    let r = Self(
      assumingElementType: Element.self, minimumCapacity: minimumCapacity)
    r.count = newCount
    
    withUnsafeMutableBufferPointer(assumingElementType: Element.self) { src in
      r.withUnsafeMutableBufferPointer(assumingElementType: Element.self) {
        dst in
        initialize(
          src.baseAddress.unsafelyUnwrapped,
          dst.baseAddress.unsafelyUnwrapped)
      }
    }
    return r
  }

  /// Creates an empty instance with `capacity` at least `minimumCapacity`.
  /// - Requires: `Element.self == elementType`
  public init<Element>(
    assumingElementType: Element.Type, minimumCapacity: Int
  ) {
    self.init(
      assumingElementType: Element.self, count: 0,
      minimumCapacity: minimumCapacity
    ) { _ in }
  }
  
  /// Creates an instance with the given `count`, and capacity at least
  /// `minimumCapacity`, and elements initialized by `initializeElements`,
  /// which is passed the address of the (uninitialized) first element.
  ///
  /// - Requires: `initializeElements` initializes exactly `count` contiguous
  ///   elements starting with the address it is passed.
  /// - Requires: `Element.self == elementType`
  /// - Requires: `count >= 0`
  public init<Element>(
    assumingElementType: Element.Type, 
    count: Int,
    minimumCapacity: Int = 0,
    initializeElements: (_ baseAddress: UnsafeMutablePointer<Element>) -> Void
  ) {
    assert(count >= 0)
    let access = Accessor_<Element>(
      bufferClass: Self.self,
      minimumCapacity: Swift.max(count, minimumCapacity)
    ) { buffer, getCapacity in 
      ArrayHeader(count: count, capacity: getCapacity(buffer))
    }
    let me = unsafeDowncast(access.buffer, to: FactoryBase.self)
    assert(me.elementType == Element.self)
    access.withUnsafeMutablePointerToElements(initializeElements)
    self.init(unsafelyAliasing: me)
  }
}

/// Contiguous storage of homogeneous elements of statically unknown type.
///
/// This class provides the element-type-agnostic API for ArrayStorage<T>.
open class AnyArrayStorage: FactoryInitializable {
  /// An instance that provides the implementation of element-type-agnostic APIs
  /// defined in this class.
  open var implementation: AnyArrayStorageImplementation {
    fatalError("implement me!")
  }
  
  /// Appends `x`, returning the index of the appended element, or `nil` if
  /// there was insufficient capacity remaining
  ///
  /// - Requires: `Element.self == elementType`
  /// - Complexity: O(1)
  public final func unsafelyAppend<Element>(_ x: Element) -> Int? {
    let r = count
    if r == capacity { return nil }
    Accessor_<Element>(unsafeBufferObject: self).withUnsafeMutablePointers {
      h, e in
      (e + r).initialize(to: x)
      h[0].count = r + 1
    }
    return r
  }

  /// Returns a copy of `self` after appending `x`, moving elements from the
  /// existing storage iff `moveElements` is true.
  ///
  /// - Postcondition: if `count == capacity` on invocation, the result's
  ///   `capacity` is `self.capacity` scaled up by a constant factor.
  ///   Otherwise, it is the same as `self.capacity`.
  /// - Postcondition: if `moveElements` is `true`, `self.count == 0`
  ///
  /// - Requires: `Element.self == elementType`
  /// - Complexity: O(N).
  public final func unsafelyAppending<Element>(
    _ x: Element, moveElements: Bool
  ) -> Self {
    let oldCount = self.count
    let oldCapacity = self.capacity
    let newCount = oldCount + 1
    let minCapacity = oldCount < oldCapacity ? oldCapacity
      : Swift.max(newCount, 2 * oldCount)
    
    if moveElements { count = 0 }
    return replacementStorage(
      assumingElementType: Element.self,
      count: newCount, minimumCapacity: minCapacity
    ) { src, dst in
      if moveElements { dst.moveInitialize(from: src, count: oldCount) }
      else { dst.initialize(from: src, count: oldCount) }
      (dst + oldCount).initialize(to: x)
    }
  }

  /// Returns the result of calling `body` on the elements of `self`.
  ///
  /// - Requires: `elementType == Element.self``
  public final func withUnsafeMutableBufferPointer<Element, R>(
    assumingElementType _: Element.Type,
    _ body: (inout UnsafeMutableBufferPointer<Element>)->R
  ) -> R {
    assert(elementType == Element.self)
    return Accessor_<Element>(unsafeBufferObject: self)
      .withUnsafeMutablePointers
    { h, e in
      var b = UnsafeMutableBufferPointer(start: e, count: h[0].count)
      return body(&b)
    }
  }

  /// The type of element stored here.
  public final var elementType: Any.Type { implementation.elementType_ }

  /// Deinitializes all stored data.
  deinit { implementation.deinitialize() }

  /// The number of elements stored in `self`.
  public final var count: Int {
    get {
      unsafeBitCast(self, to: ArrayHeaderAccess.self).header.count
    }
    _modify {
      defer { _fixLifetime(self) }
      yield &unsafeBitCast(self, to: ArrayHeaderAccess.self).header.count
    }
  }

  /// The maximum number of elements that can be stored in `self`.
  public final var capacity: Int {
    unsafeBitCast(self, to: ArrayHeaderAccess.self).header.capacity
  }

  /// Returns a distinct, uniquely-referenced, copy of `self`.
  public final func makeCopy() -> Self {
    unsafeDowncast(implementation.makeCopy_(), to: Self.self)
  }
}

/// A class that is never instantiated, used usafely to get access to the header
/// fields from a type-erased `AnyArrayStorage` instance.
private final class ArrayHeaderAccess {
  init?() { fatalError("Don't ever construct me") }
  var header: ArrayHeader
}

/// Contiguous storage of homogeneous elements of statically unknown type.
///
/// Conformances to this protocol provide the implementations for
/// `AnyArrayStorage` APIs.
public protocol AnyArrayStorageImplementation: AnyArrayStorage {
  /// The type of element stored here.
  var elementType_: Any.Type { get }
  
  /// Deinitialize stored data
  func deinitialize()

  /// Returns a distinct, uniquely-referenced, copy of `self`.
  func makeCopy_() -> Self
}

extension AnyArrayStorageImplementation {
  /// A position in the storage
  public typealias Index = Int
  
  /// The position of the first element.
  public var startIndex: Index { 0 }
  
  /// The position just past the last element.
  public var endIndex: Index { count }
}

/// Contiguous storage of homogeneous elements of statically known type.
///
/// This protocol's extensions provide APIs that depend on the element type, and
/// the implementations for `AnyArrayStorage` APIs.
public protocol ArrayStorageImplementation
  : AnyArrayStorageImplementation,
    RandomAccessCollection, MutableCollection
{
  associatedtype Element
}

/// APIs that depend on the `Element` type.
extension ArrayStorageImplementation {
  /// Creates an instance with the same elements as `contents`, having a
  /// `capacity` of at least `minimumCapacity`.
  public init<Contents: Collection>(
    _ contents: Contents, minimumCapacity: Int = 0
  )
    where Contents.Element == Element
  {
    let count = contents.count
    self.init(count: count, minimumCapacity: minimumCapacity) { baseAddress in
      for (i, e) in contents.enumerated() {
        (baseAddress + i).initialize(to: e)
      }
    }
  }
  
  /// Accesses the element at `i`.
  ///
  /// - Requires: `i >= 0 && i < count`.
  /// - Note: this is not a memory-safe API; if `i` is out-of-range, the
  ///   behavior is undefined.
  public subscript(i: Int) -> Element {
    _read {
      assert(i >= 0 && i < count, "index out of range")
      yield access.withUnsafeMutablePointers { _, base in base[i] }
    }
    _modify {
      defer { _fixLifetime(self) }
      let base = access.withUnsafeMutablePointers { _, base in base }
      yield &base[i]
    }
  }
  
  /// A type whose instances can be used to access the memory of `self` with a
  /// degree of type-safety.
  private typealias Accessor = Accessor_<Element>

  /// A handle to the memory of `self` providing a degree of type-safety.
  private var access: Accessor { .init(unsafeBufferObject: self) }

  /// Returns a distinct, uniquely-referenced, copy of `self`.
  public func makeCopy_() -> Self {
    replacementStorage(count: count, minimumCapacity: capacity) { 
      [count] source, destination in
      destination.initialize(from: source, count: count)
    }
  }
  
  /// Appends `x` if possible, returning the index of the appended element or
  /// `nil` if there was insufficient capacity remaining.
  public func append(_ x: Element) -> Int? {
    unsafelyAppend(x)
  }
  
  /// Returns new storage having at least the given capacity, calling
  /// `initialize` with pointers to the base addresses of self and the new
  /// storage.
  public func replacementStorage(
    count newCount: Int,
    minimumCapacity: Int,
    initialize: (
      _ selfBase: UnsafeMutablePointer<Element>,
      _ replacementBase: UnsafeMutablePointer<Element>) -> Void
  ) -> Self {
    replacementStorage(
      assumingElementType: Element.self, count: newCount,
      minimumCapacity: minimumCapacity, initialize: initialize)
  }

  /// Returns a copy of `self` after appending `x`, moving elements from the
  /// existing storage iff `moveElements` is true.
  ///
  /// - Postcondition: if `count == capacity` on invocation, the result's
  ///   `capacity` is `self.capacity` scaled up by a constant factor.
  ///   Otherwise, it is the same as `self.capacity`.
  /// - Postcondition: if `moveElements` is `true`, `self.count == 0`
  ///
  /// - Complexity: O(N).
  @inline(never) // this is the slow path for ArrayBuffer.append()
  public func appending(_ x: Element, moveElements: Bool) -> Self {
    unsafelyAppending(x, moveElements: moveElements)
  }
  
  /// Invokes `body` with the memory occupied by stored elements.
  public func withUnsafeMutableBufferPointer<R>(
    _ body: (inout UnsafeMutableBufferPointer<Element>) -> R
  ) -> R {
    withUnsafeMutableBufferPointer(assumingElementType: Element.self, body)
  }

  /// Creates an empty instance with `capacity` at least `minimumCapacity`.
  public init(minimumCapacity: Int) {
    let access = Accessor(
      bufferClass: Self.self, minimumCapacity: minimumCapacity
    ) { buffer, getCapacity in 
      ArrayHeader(count: 0, capacity: getCapacity(buffer))
    }
    
    self.init(
      unsafelyAliasing: unsafeDowncast(access.buffer, to: FactoryBase.self))
  }
  
  /// Creates an instance with the given `count`, and capacity at least
  /// `minimumCapacity`, and elements initialized by `initializeElements`,
  /// which is passed the address of the (uninitialized) first element.
  ///
  /// - Requires: `initializeElements` initializes exactly `count` contiguous
  ///   elements starting with the address it is passed.
  public init(
    count: Int,
    minimumCapacity: Int = 0,
    initializeElements:
      (_ uninitializedElements: UnsafeMutablePointer<Element>) -> Void
  ) {
    let access = ManagedBufferPointer<ArrayHeader, Element>(
      bufferClass: Self.self,
      minimumCapacity: Swift.max(count, minimumCapacity)
    ) { buffer, getCapacity in 
      ArrayHeader(count: count, capacity: getCapacity(buffer))
    }
    access.withUnsafeMutablePointerToElements(initializeElements)
    self.init(
      unsafelyAliasing: unsafeDowncast(access.buffer, to: FactoryBase.self))
  }
}

/// Implementation of `AnyArrayStorageImplementation` requirements
extension ArrayStorageImplementation {
  /// Deinitialize stored data. Models should call this from their `deinit`.
  public func deinitialize() {
    access.withUnsafeMutablePointers { h, e in
      e.deinitialize(count: h[0].count)
      h.deinitialize(count: 1)
    }
  }

  /// The type of element stored here.
  public var elementType_: Any.Type { Element.self }
}

/// Type-erasable storage for contiguous `Element` instances.
///
/// Note: instances of `ArrayStorage` have reference semantics.
public final class ArrayStorage<Element>:
  AnyArrayStorage, ArrayStorageImplementation
{
  override public var implementation: AnyArrayStorageImplementation { self }
}
