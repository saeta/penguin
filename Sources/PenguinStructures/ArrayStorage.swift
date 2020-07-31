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

/// `AnyArrayStorage` things that pertain to initialization.
extension FactoryInitializable where Self: AnyArrayStorage {
  /// A way to access the storage when the element type is known
  fileprivate typealias Accessor_<Element>
    = ManagedBufferPointer<ArrayHeader, Element>
}

/// Contiguous storage of homogeneous elements of statically unknown type.
///
/// This class provides the element-type-agnostic API for ArrayStorage<T>.
open class AnyArrayStorage: FactoryInitializable {    
  public func makeCopy() -> Self { fatalError("implement me as clone()") }
  
  /// The type of element stored here.
  fileprivate class var elementType: TypeID {
    fatalError("implement me as .init(Element.self)")
  }

  /// The type of element stored here.
  ///
  /// - Note: a convenience, but also a workaround for
  ///   https://bugs.swift.org/browse/SR-12988
  fileprivate final var elementType: TypeID { Self.elementType }

  /// Returns `true` iff `self` may be used as the storage for elements of type `e`.
  public final func isUsable(forElementType e: TypeID) -> Bool {
    return self === Self.zeroCapacityInstance || elementType == e
  }
}

extension AnyArrayStorage {
  /// The number of elements stored in `self`.
  ///
  /// - Invariant: `count <= capacity`
  public fileprivate(set) final var count: Int {
    get {
      Accessor_<Never>(unsafeBufferObject: self).withUnsafeMutablePointerToHeader {
        h in h.pointee.count
      }
    }
    set {
      Accessor_<Never>(unsafeBufferObject: self).withUnsafeMutablePointerToHeader {
        assert(newValue <= $0.pointee.capacity)
        $0.pointee.count = newValue
      }
    }
  }

  /// The maximum number of elements that can be stored in `self`.
  public final var capacity: Int {
    Accessor_<Never>(unsafeBufferObject: self).withUnsafeMutablePointerToHeader {
      $0.pointee.capacity
    }
  }

  /// The universal empty instance
  internal static var zeroCapacityInstance: AnyArrayStorage = unsafeDowncast(
    Accessor_<Never>(bufferClass: ArrayStorage<Never>.self, minimumCapacity: 0) { _, _ in
      ArrayHeader(count: 0, capacity: 0)
    }.buffer, to: AnyArrayStorage.self)

  /// Returns `self`, recast as an `ArrayStorage<Element>`.
  ///
  /// - Requires: `self` is the empty instance, or `self` actually has the dynamic type
  ///   `ArrayStorage<Element>`.
  internal func unsafelyDowncastingElements<Element>(to _: Type<Element>) -> ArrayStorage<Element> {
    assert(isUsable(forElementType: Type<Element>.id), "invalid down-cast.")
    return unsafeBitCast(self as AnyObject, to: ArrayStorage<Element>.self)
  }
}

public protocol ArrayStorageProtocol: AnyArrayStorage, RandomAccessCollection, MutableCollection
where Index == Int
{
  associatedtype Element  
}

/// Type-erasable storage for contiguous `Element` instances.
///
/// Note: instances of `ArrayStorage` have reference semantics.
public final class ArrayStorage<Element>: AnyArrayStorage, ArrayStorageProtocol {
  public typealias Element = Element

  deinit {
    access.withUnsafeMutablePointers {
      h, e in
      e.deinitialize(count: h.pointee.count)
      h.deinitialize(count: 1)
    }
  }

  /// The type of element stored here.
  fileprivate final override class var elementType: TypeID { .init(Element.self) }

  /// Returns a distinct, uniquely-referenced, copy of `self`—unless its capacity is 0, in which
  /// case it returns `self`.
  public final override func makeCopy() -> Self {
    if capacity == 0 { return self }
    let count = self.count
    return replacementStorage(count: count, minimumCapacity: capacity) {
      selfBase, replacementBase in
      replacementBase.initialize(from: selfBase, count: count)
    }
  }

}  

extension ArrayStorageProtocol { 
  /// A type whose instances can be used to access the memory of `self` with a
  /// degree of type-safety.
  fileprivate typealias Accessor = Accessor_<Element>

  /// A handle to the memory of `self` providing a degree of type-safety.
  fileprivate var access: Accessor { .init(unsafeBufferObject: self) }
  
  /// Creates an instance with the same elements as `contents`, having a
  /// `capacity` of at least `minimumCapacity`.
  public init<Contents: Collection>(
    _ contents: Contents, minimumCapacity: Int = 0
  )
    where Contents.Element == Element
  {
    let count = contents.count
    self.init(count: count, minimumCapacity: minimumCapacity) { baseAddress in
      var p = baseAddress
      for e in contents {
        p.initialize(to: e)
        p += 1
      }
    }
  }
  
  /// Creates an empty instance with `capacity` at least `minimumCapacity`.
  public init(minimumCapacity: Int = 0) {
    self.init(count: 0, minimumCapacity: minimumCapacity) { _ in }
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
    let capacityRequest = Swift.max(count, minimumCapacity)
    if capacityRequest == 0 {
      self.init(unsafelyBitCasting: Self.zeroCapacityInstance)
      return
    }
    let access = Accessor_<Element>(
      bufferClass: Self.self,
      minimumCapacity: capacityRequest
    ) { buffer, getCapacity in 
      ArrayHeader(count: count, capacity: getCapacity(buffer))
    }
    access.withUnsafeMutablePointerToElements(initializeElements)
    
    self.init(unsafelyAliasing: unsafeDowncast(access.buffer, to: FactoryBase.self))
  }
  
  /// Returns the result of calling `body` on the elements of `self`.
  public func withUnsafeMutableBufferPointer<R>(
    _ body: (inout UnsafeMutableBufferPointer<Element>)->R
  ) -> R {
    return access.withUnsafeMutablePointers {
      h, e in
      var b = UnsafeMutableBufferPointer(start: e, count: h[0].count)
      return body(&b)
    }
  }

  /// Returns new storage having at least the given capacity, calling
  /// `initialize` with pointers to the base addresses of self and the new
  /// storage.
  ///
  /// - Requires: `self.isUsable(forElementType: TypeID(Element.self))`
  public func replacementStorage(
    count newCount: Int,
    minimumCapacity: Int,
    initialize: (
      _ selfBase: UnsafeMutablePointer<Element>,
      _ replacementBase: UnsafeMutablePointer<Element>) -> Void
  ) -> Self {
    assert(self.isUsable(forElementType: TypeID(Element.self)))
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
      : Swift.max(newCount, 2 * oldCount)
    
    if moveElements { count = 0 }
    return replacementStorage(
      count: newCount, minimumCapacity: minCapacity
    ) { src, dst in
      if moveElements { dst.moveInitialize(from: src, count: oldCount) }
      else { dst.initialize(from: src, count: oldCount) }
      (dst + oldCount).initialize(to: x)
    }
  }

  /// Appends `x`, returning the index of the appended element, or `nil` if
  /// there was insufficient capacity remaining
  ///
  /// - Complexity: O(1)
  public func append(_ x: Element) -> Int? {
    let r = count
    if r == capacity { return nil }
    access.withUnsafeMutablePointers {
      h, e in
      (e + r).initialize(to: x)
      h[0].count = r + 1
    }
    return r
  }
}

extension ArrayStorageProtocol /*: RandomAccessCollection, MutableCollection*/ {
  /// The position of the first element.
  public var startIndex: Index { 0 }
  
  /// The position just past the last element.
  public var endIndex: Index { count }

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
}
