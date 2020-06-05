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

/// Contiguous storage of homogeneous elements of statically unknown type.
///
/// This class provides the element-type-agnostic API for ArrayStorage<T>.
open class AnyArrayStorage {
  /// An instance that provides the implementation of element-type-agnostic APIs
  /// defined in this class.
  open var implementation: AnyArrayStorageImplementation {
    fatalError("implement me!")
  }
  
  /// Appends the instance of the concrete element type whose address is `p`,
  /// returning the index of the appended element, or `nil` if there was
  /// insufficient capacity remaining
  ///
  /// - Complexity: O(1)
  public final func appendValue(at p: UnsafeRawPointer) -> Int? {
    implementation.appendValue_(at: p)
  }

  /// Returns a copy of `self` after appending the instance of the concrete
  /// element type whose address is `p`, moving elements from the existing
  /// storage iff `moveElements` is true.
  ///
  /// - Postcondition: if `count == capacity` on invocation, the result's
  ///   `capacity` is `self.capacity` scaled up by a constant factor.
  ///   Otherwise, it is the same as `self.capacity`.
  /// - Postcondition: if `moveElements` is `true`, `self.count == 0`
  ///
  /// - Complexity: O(N).
  public final func appendingValue(
    at p: UnsafeRawPointer, moveElements: Bool
  ) -> Self {
    unsafeDowncast(
      implementation.appendingValue_(at: p, moveElements: moveElements),
      to: Self.self)
  }

  /// Invokes `body` with the memory occupied by initialized elements.
  public final func withUnsafeMutableRawBufferPointer<R>(
    _ body: (inout UnsafeMutableRawBufferPointer)->R
  ) -> R {
    implementation.withUnsafeMutableRawBufferPointer_(body)
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
  /// Appends the instance of the concrete element type whose address is `p`,
  /// returning the index of the appended element, or `nil` if there was
  /// insufficient capacity remaining
  ///
  /// - Complexity: O(1)
  func appendValue_(at p: UnsafeRawPointer) -> Int?
  
  /// Returns a copy of `self` after appending the instance of the concrete
  /// element type whose address is `p`, moving elements from the existing
  /// storage iff `moveElements` is true.
  ///
  /// - Postcondition: if `count == capacity` on invocation, the result's
  ///   `capacity` is `self.capacity` scaled up by a constant factor.
  ///   Otherwise, it is the same as `self.capacity`.
  /// - Postcondition: if `moveElements` is `true`, `self.count == 0`
  ///
  /// - Complexity: O(N).
  func appendingValue_(at p: UnsafeRawPointer, moveElements: Bool) -> Self

  /// Invokes `body` with the memory occupied by initialized elements.
  func withUnsafeMutableRawBufferPointer_<R>(
    _ body: (inout UnsafeMutableRawBufferPointer)->R
  ) -> R

  /// The type of element stored here.
  var elementType_: Any.Type { get }
  
  /// Deinitialize stored data
  func deinitialize()
}

/// Contiguous storage of homogeneous elements of statically known type.
///
/// This protocol's extensions provide APIs that depend on the element type, and
/// the implementations for `AnyArrayStorage` APIs.
public protocol ArrayStorageImplementation
  : AnyArrayStorageImplementation, FactoryInitializable
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
  
  /// A type whose instances can be used to access the memory of `self` with a
  /// degree of type-safety.
  private typealias Accessor = ManagedBufferPointer<ArrayHeader, Element>

  /// A handle to the memory of `self` providing a degree of type-safety.
  private var access: Accessor { .init(unsafeBufferObject: self) }

  /// Appends `x` if possible, returning the index of the appended element or
  /// `nil` if there was insufficient capacity remaining.
  public func append(_ x: Element) -> Int? {
    let r = count
    if r == capacity { return nil }
    access.withUnsafeMutablePointers { h, e in
      (e + r).initialize(to: x)
      h[0].count = r + 1
    }
    return r
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
    assert(minimumCapacity >= newCount)
    let r = Self(minimumCapacity: minimumCapacity)
    r.count = newCount
    
    withUnsafeMutableBufferPointer { src in
      r.withUnsafeMutableBufferPointer { dst in
        initialize(
          src.baseAddress.unsafelyUnwrapped,
          dst.baseAddress.unsafelyUnwrapped)
      }
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
  /// - Complexity: O(N).
  @inline(never) // this is the slow path for ArrayBuffer.append()
  public func appending(_ x: Element, moveElements: Bool) -> Self {
    let oldCount = self.count
    let oldCapacity = self.capacity
    let newCount = oldCount + 1
    let minCapacity = oldCount < oldCapacity ? oldCapacity
      : max(newCount, 2 * oldCount)
    
    if moveElements { count = 0 }
    return replacementStorage(
      count: newCount, minimumCapacity: minCapacity
    ) { src, dst in
      if moveElements { dst.moveInitialize(from: src, count: oldCount) }
      else { dst.initialize(from: src, count: oldCount) }
      (dst + oldCount).initialize(to: x)
    }
  }
  
  /// Invokes `body` with the memory occupied by stored elements.
  public func withUnsafeMutableBufferPointer<R>(
    _ body: (inout UnsafeMutableBufferPointer<Element>) -> R
  ) -> R {
    access.withUnsafeMutablePointers { h, e in
      var b = UnsafeMutableBufferPointer(start: e, count: h[0].count)
      return body(&b)
    }
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
    initializeElements: (_ baseAddress: UnsafeMutablePointer<Element>) -> Void
  ) {
    let access = Accessor(
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
  /// Appends the instance of the concrete element type whose address is `p`,
  /// returning the index of the appended element, or `nil` if there was
  /// insufficient capacity remaining
  public func appendValue_(at p: UnsafeRawPointer) -> Int? {
    append(p.assumingMemoryBound(to: Element.self)[0])
  }

  /// Returns a copy of `self` after appending the instance of the concrete
  /// element type whose address is `p`, moving elements from the existing
  /// storage iff `moveElements` is true.
  ///
  /// - Postcondition: if `count == capacity` on invocation, the result's
  ///   `capacity` is `self.capacity` scaled up by a constant factor.
  ///   Otherwise, it is the same as `self.capacity`.
  /// - Postcondition: if `moveElements` is `true`, `self.count == 0`
  /// - Complexity: O(N).
  public func appendingValue_(at p: UnsafeRawPointer, moveElements: Bool) -> Self {
    self.appending(
      p.assumingMemoryBound(to: Element.self)[0], moveElements: moveElements)
  }

  /// Invokes `body` with the memory occupied by initialized elements.
  public func withUnsafeMutableRawBufferPointer_<R>(
    _ body: (inout UnsafeMutableRawBufferPointer)->R
  ) -> R {
    withUnsafeMutableBufferPointer {
      var b = UnsafeMutableRawBufferPointer($0)
      return body(&b)
    }
  }

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
