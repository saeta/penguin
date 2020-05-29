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

  /// Invokes `body` with the memory occupied by initialized elements.
  public final func withUnsafeMutableRawBufferPointer<R>(
    _ body: (inout UnsafeMutableRawBufferPointer)->R
  ) -> R {
    implementation.withUnsafeMutableRawBufferPointer_(body)
  }

  /// Deinitializes all stored data.
  deinit { implementation.deinitialize() }
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
  /// Complexity: O(1)
  func appendValue_(at p: UnsafeRawPointer) -> Int?
  
  /// Invokes `body` with the memory occupied by initialized elements.
  func withUnsafeMutableRawBufferPointer_<R>(
    _ body: (inout UnsafeMutableRawBufferPointer)->R
  ) -> R

  /// Deinitialize stored data
  func deinitialize()
}

/// Contiguous storage of homogeneous elements of statically known type.
///
/// This protocol's extensions provide APIs that depend on the element type, and
/// the implementations for `AnyArrayStorage` APIs.
public protocol ArrayStorageImplementation: AnyArrayStorageImplementation {
  associatedtype Element
}

/// APIs that depend on the `Element` type.
extension ArrayStorageImplementation {
  /// A type whose instances can be used to access the memory of `self` with a
  /// degree of type-safety.
  private typealias Accessor = ManagedBufferPointer<ArrayHeader, Element>

  /// A handle to the memory of `self` providing a degree of type-safety.
  private var access: Accessor { .init(unsafeBufferObject: self) }

  /// The number of elements stored in `self`.
  public var count: Int {
    _read { yield access.withUnsafeMutablePointerToHeader { $0.pointee.count } }
    _modify {
      defer { _fixLifetime(self) }
      yield &access.withUnsafeMutablePointerToHeader { $0 }.pointee.count
    }
  }

  /// The maximum number of elements that can be stored in `self`.
  public var capacity: Int {
    _read {
      yield access.withUnsafeMutablePointerToHeader {
        $0.pointee.capacity }
    }
    _modify {
      defer { _fixLifetime(self) }
      yield &access.withUnsafeMutablePointerToHeader { $0 }.pointee.capacity
    }
  }
  
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

  /// Invokes `body` with the memory occupied by stored elements.
  public func withUnsafeMutableBufferPointer<R>(
    _ body: (inout UnsafeMutableBufferPointer<Element>) -> R
  ) -> R {
    access.withUnsafeMutablePointers { h, e in
      var b = UnsafeMutableBufferPointer(start: e, count: h[0].count)
      return body(&b)
    }
  }

  /// Returns an empty instance with `capacity` at least `minimumCapacity`.
  public static func create(minimumCapacity: Int) -> Self {
    unsafeDowncast(
      Accessor(
        bufferClass: Self.self, minimumCapacity: minimumCapacity
      ) { buffer, getCapacity in 
        ArrayHeader(count: 0, capacity: getCapacity(buffer))
      }.buffer,
      to: Self.self)
  }

  private init() { fatalError("Please call create()") }
}

/// Implementation of `AnyArrayStorageImplementation` requirements
extension ArrayStorageImplementation {
  /// Appends the instance of the concrete element type whose address is `p`,
  /// returning the index of the appended element, or `nil` if there was
  /// insufficient capacity remaining
  public func appendValue_(at p: UnsafeRawPointer) -> Int? {
    append(p.assumingMemoryBound(to: Element.self)[0])
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
}

/// Type-erasable storage for contiguous `Element` instances.
///
/// Note: instances of `ArrayStorage` have reference semantics.
public final class ArrayStorage<Element>:
  AnyArrayStorage, ArrayStorageImplementation
{
  override public var implementation: AnyArrayStorageImplementation { self }
}
