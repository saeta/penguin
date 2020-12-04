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

fileprivate extension MemoryLayout {
  /// True iff `T` instances are stored in an existential's inline buffer space.
  static var fitsExistentialInlineBuffer: Bool {
    MemoryLayout<(T, Any.Type)>.size <= MemoryLayout<Any>.size
      && self.alignment <= MemoryLayout<Any>.alignment
      && _isBitwiseTakable(T.self)
  }
}

/// A wrapper for a value of any type, with efficient access and inline storage of bounded size for
/// small values.
///
/// Existential types such as `Any` provide the storage characteristics of `AnyValue`, but many
/// operations on existentials [optimize poorly](https://bugs.swift.org/browse/SR-13438), so
/// `AnyValue` may be needed to achieve efficient access.
///
/// Using `enums` and no existential, it is possible to build such storage for:
/// - types that are trivially copiable (such as Int), or
/// - collections of elements with the inline storage being (roughly) a multiple of the element
///   size.
/// You might consider using the `enum` approach where applicable.
public struct AnyValue {
  /// The memory layout of `Any` instances.
  private typealias AnyLayout = (inlineStorage: (Int, Int, Int), storedType: Any.Type)

  /// The underlying storage of the value.
  ///
  /// Types that fit the inline storage of `Any` are stored directly, by assignment. Although `Any`
  /// has its own boxing mechanism for types that don't fit its inline storage, it is apparently
  /// incompatible with our needs for mutation (https://bugs.swift.org/browse/SR-13460) and
  /// seem to be needlessly reallocated in some cases.  Therefore, larger types are stored
  /// indirectly in a class instance of static type `BoxBase`. Object references fit the inline
  /// storage of `Any`, so the value held *directly* by `storage` is always stored in its inline
  /// buffer.
  fileprivate var storage: Any

  /// Creates an instance that stores `x`.
  ///
  /// - Postcondition: where `a` is the created instance, `a.storedType == T.self`, and `a[T.self]`
  ///   is equivalent to `x`.
  public init<T>(_ x: T) {
    if MemoryLayout<T>.fitsExistentialInlineBuffer { storage = x}
    else { storage = Box(x) as BoxBase }
  }

  /// The type of the value held directly by `storage`.
  ///
  /// If the type stored in `self` does not fit the inline storage of an existential,
  /// `directlyStoredType` will be `BoxBase.self`.
  private var directlyStoredType: Any.Type {    
    // Note: using withUnsafePointer(to: storage) rather than withUnsafePointer(to: self) produces a
    // copy of storage, and thus much worse code (https://bugs.swift.org/browse/SR-13462).
    return Swift.withUnsafePointer(to: self) { // https://bugs.swift.org/browse/SR-13462
      UnsafeRawPointer($0).assumingMemoryBound(to: AnyLayout.self)[0].storedType
    }
  }

  /// The type of the value stored in `self`.
  public var storedType: Any.Type {
    let d = directlyStoredType
    if d != Self.boxType { return d }
    return self[unsafelyAssuming: Type<BoxBase>()].storedType
  }

  /// Returns a pointer to the `T` which is assumed to be stored in `self`.
  private func pointer<T>(toStored _: Type<T>) -> UnsafePointer<T> {
    // Note: using withUnsafePointer(to: storage) rather than withUnsafePointer(to: self) produces a
    // copy of storage, and thus much worse code (https://bugs.swift.org/browse/SR-13462).
    return withUnsafePointer(to: self) {
      let address = UnsafeRawPointer($0)
      if MemoryLayout<T>.fitsExistentialInlineBuffer {
        return address.assumingMemoryBound(to: T.self)
      }
      else {
        let boxBase = address.assumingMemoryBound(to: Self.boxType).pointee
        let box = unsafeDowncast(boxBase, to: Box<T>.self)
        return box.valuePointerWorkaround
      }
    }
  }

  /// A dynamically-allocated box storing a statically-unknown type that doesn't fit in an
  /// existential's inline buffer.
  private class BoxBase {
    /// The type stored in this box.
    final let storedType: Any.Type

    /// Creates an instance with the given `storedType`
    fileprivate init(storedType: Any.Type) {
      self.storedType = storedType
    }

    /// Returns the boxed value.
    fileprivate var asAny: Any { fatalError("override me") }
  }

  /// Cached type metadata (see https://bugs.swift.org/browse/SR-13459)
  private static let boxType = BoxBase.self

  /// A box holding a value of type `T`, which wouldn't fit in an existential's inline buffer.
  ///
  /// - Note: it's crucial to always cast a `Box` instance to `BoxBase` before assigning it into
  ///   `storage.`
  private final class Box<T>: BoxBase {
    /// The boxed value
    var value: T

    /// Creates an instance storing `value`
    ///
    /// - Requires: !MemoryLayout<T>.fitsExistentialInlineBuffer
    init(_ value: T) {
      assert(
        !MemoryLayout<T>.fitsExistentialInlineBuffer, "Boxing a value that should be stored inline")
      assert(!(value is BoxBase), "unexpectedly boxing a box!")
      self.value = value
      super.init(storedType: T.self)
    }

    /// Returns the boxed value.
    fileprivate override var asAny: Any { value }

    /// Returns a pointer to `value`.
    // TODO(#131): This works around a compiler crash. Remove this workaround after the crash is
    // fixed.
    @inline(never)
    fileprivate var valuePointerWorkaround: UnsafePointer<T> {
      withUnsafeMutablePointer(to: &value) { .init($0) }
    }
  }
  
  /// Returns a pointer to the `T` which is assumed to be stored in `self`.
  ///
  /// If the `T` is stored in a shared box, the box is first copied to make it unique.
  ///
  /// - Requires: `storedType == T.self`
  private mutating func mutablePointer<T>(toStored _: Type<T>) -> UnsafeMutablePointer<T> {
    let address: UnsafeMutableRawPointer = withUnsafeMutablePointer(to: &storage) { .init($0) }
    if MemoryLayout<T>.fitsExistentialInlineBuffer {
      return address.assumingMemoryBound(to: T.self)
    }
    if !isKnownUniquelyReferenced(&self[unsafelyAssuming: Type<BoxBase>()]) {
      rebox(stored: Type<T>())
    }
    let boxBase = address.assumingMemoryBound(to: Self.boxType).pointee
    let box = unsafeDowncast(boxBase, to: Box<T>.self)
    return withUnsafeMutablePointer(to: &box.value) { $0 }
  }

  /// Copies the boxed `T`.
  ///
  /// - Requires: `storedType == T.self`
  /// - Requires: `!MemoryLayout<T>.fitsExistentialInlineBuffer`
  // TODO: see if this is really best done out-of-line, considering that `isKnownUniquelyReferenced`
  // is already a function call.
  @inline(never)
  private mutating func rebox<T>(stored _: Type<T>) {
    storage = Box(self[unsafelyAssuming: Type<T>()]) as BoxBase
  }

  /// Iff `storedType != T.self`, traps with an appropriate error message.
  private func typeCheck<T>(_: Type<T>) {
    if storedType != T.self { typeCheckFailure(T.self) }
  }

  /// Traps with an appropriate error message assuming that `storedType != T.self`.
  @inline(never)
  private func typeCheckFailure(_ expectedType: Any.Type) {
    fatalError("stored type \(storedType) != \(expectedType)")
  }

  /// Accesses the `T` stored in `self`.
  ///
  /// - Requires: `storedType == T.self`.
  @inline(__always) // Compiler likes to skip inlining this otherwise.
  public subscript<T>(_: Type<T>) -> T {
    get {
      defer { _fixLifetime(self) }
      typeCheck(Type<T>())
      return pointer(toStored: Type<T>()).pointee
    }
    _modify {
      typeCheck(Type<T>())
      defer { _fixLifetime(self) }
      yield &mutablePointer(toStored: Type<T>()).pointee
    }
  }

  /// Unsafely accesses the `T` stored in `self`.
  ///
  /// - Requires: `storedType == T.self`.
  @inline(__always) // Compiler likes to skip inlining this otherwise.
  public subscript<T>(unsafelyAssuming _: Type<T>) -> T {
    get {
      defer { _fixLifetime(self) }
      return pointer(toStored: Type<T>()).pointee
    }
    _modify {
      defer { _fixLifetime(self) }
      yield &mutablePointer(toStored: Type<T>()).pointee
    }
  }

  /// Stores `x` in `self`.
  ///
  /// This may be more efficient than `self = AnyValue(x)` because it uses the same allocated buffer
  /// when possible for large types.
  public mutating func store<T>(_ x: T) {
    defer { _fixLifetime(self) }
    if storedType == T.self { mutablePointer(toStored: Type<T>()).pointee = x }
    else { self = .init(x) }
  }

  /// The stored value.
  ///
  /// This property can be useful for interoperability with the rest of Swift, especially when you
  /// don't know the full dynamic type of the stored value.
  public var asAny: Any {
    if directlyStoredType != Self.boxType { return storage }
    return self[unsafelyAssuming: Type<BoxBase>()].asAny
  }

  /// If the stored value is boxed or is an object, returns the ID of the box or object; returns
  /// `nil` otherwise.
  ///
  /// Used only by tests.
  internal var boxOrObjectID_testable: ObjectIdentifier? {
    if !(directlyStoredType is AnyObject.Type) { return nil }
    return .init(self[unsafelyAssuming: Type<AnyObject>()])
  }
}

extension AnyValue: CustomStringConvertible, CustomDebugStringConvertible {
  /// A textual representation of this instance.
  public var description: String { String(describing: storage) }

  /// A string, suitable for debugging, that represents the instance.
  public var debugDescription: String { "AnyValue(\(String(reflecting: storage)))" }
}
