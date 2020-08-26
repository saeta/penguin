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

import Benchmark
import PenguinStructures

// -------------------------------------------------------------------------------------------------
// Benchmarking Strategy:
//
// - Use `AnyValue` as substrate for type-erased `AnyMutableCollection_`.
// - Also use two other type erasure techniques as substrate.
// - Benchmark the same operations on the `AnyMutableCollection_` using all 3 substrates.
// -------------------------------------------------------------------------------------------------

/// Prevents the value of `x` from being discarded by the optimizer.
///
/// TODO: when https://github.com/google/swift-benchmark/issues/69 is resolved consider using that
/// facility instead.
@inline(__always)
fileprivate func doNotOptimizeAway<T>(_ x: T) {
  
  @_optimize(none) 
  func assumePointeeIsRead(_ x: UnsafeRawPointer) {}
  
  withUnsafePointer(to: x) { assumePointeeIsRead($0) }
}

/// Returns `x`, preventing its value from being statically known by the optimizer.
///
/// TODO: when https://github.com/google/swift-benchmark/issues/74 is resolved consider using that
/// facility instead.
@inline(__always)
fileprivate func hideValue<T>(_ x: T) -> T {
  
  @_optimize(none) 
  func assumePointeeIsWritten<T>(_ x: UnsafeMutablePointer<T>) {}
  
  var copy = x
  withUnsafeMutablePointer(to: &copy) { assumePointeeIsWritten($0) }
  return copy
}

//
// Storage for “vtables” implementing operations on type-erased values.
//
// Large tables of Swift functions are expensive if stored inline, and incur ARC and allocation
// costs if stored in classes.  We want to allocate them once, keep them alive forever, and
// reference them with cheap unsafe pointers.
//
// We therefore need a vtable cache.  For thread-safety, we could share a table and use a lock, but
// the easiest answer for now is use a thread-local cache per thread.
typealias TLS = PosixConcurrencyPlatform_.ThreadLocalStorage

/// Holds the lookup table for vtables.  TLS facilities require that this be a class type.
fileprivate class VTableCache {
  /// A map from a pair of types (`Wrapper`, `Wrapped`) to the address of a VTable containing the
  /// implementation of `Wrapper` operations in terms of `Wrapped` operations.
  var tables: [Array2<TypeID>: UnsafeRawPointer] = [:]
  init() {}
}

/// Lookup key for the thread-local vtable cache.
fileprivate let vTableCacheKey = TLS.makeKey(for: Type<VTableCache>())

/// Constructs a vtable cache instance for the current thread.
@inline(never)
fileprivate func makeVTableCache() -> VTableCache {
  let r = VTableCache()
  TLS.set(r, for: vTableCacheKey)
  return r
}

/// Returns a pointer the table corresponding to `tableID`, creating it by invoking `create` if it
/// is not already available.
fileprivate func demandVTable<Table>(_ tableID: Array2<TypeID>, create: ()->Table)
  -> UnsafePointer<Table>
{
  /// Returns a pointer to a globally-allocated copy of the result of `create`, registering it
  /// in `tableCache`.
  @inline(never)
  func makeAndCacheTable(in cache: VTableCache) -> UnsafePointer<Table> {
    let r = UnsafeMutablePointer<Table>.allocate(capacity: 1)
    r.initialize(to: create())
    cache.tables[tableID] = .init(r)
    return .init(r)
  }
  
  let slowPathCache: VTableCache
  
  if let cache = TLS.get(vTableCacheKey) {
    if let r = cache.tables[tableID] { return r.assumingMemoryBound(to: Table.self) }
    slowPathCache = cache
  }
  else {
    slowPathCache = makeVTableCache()
  }
  return makeAndCacheTable(in: slowPathCache)
}

/// The API of types that can be used by `AnyMutableCollection_` as type-erased storage substrate.
///
/// See the strategy note at the top of this file for details.
internal protocol AnyValueProtocol {
  /// Creates an instance that stores `x`.
  ///
  /// - Postcondition: where `a` is the created instance, `a.storedType == T.self`, and `a[T.self]`
  ///   is equivalent to `x`.
  init<T>(_ x: T)
  
  /// The type of the value stored in `self`.
  var storedType: Any.Type { get }

  /// Accesses the `T` stored in `self`.
  ///
  /// - Requires: `storedType == T.self`.
  subscript<T>(_: Type<T>) -> T { get set }

  /// Unsafely accesses the `T` stored in `self`.
  ///
  /// - Requires: `storedType == T.self`.
  subscript<T>(unsafelyAssuming _: Type<T>) -> T { get set }

  /// Stores `x` in `self`.
  mutating func store<T>(_ x: T)

  /// The stored value.
  var asAny: Any { get }
}

extension AnyValue: AnyValueProtocol {}

/// Type-erased storage substrate based on direct, naïve use of `Any`
internal struct NaiveAnyBased_AnyValue: AnyValueProtocol {
  var storage: Any
  
  /// Creates an instance that stores `x`.
  ///
  /// - Postcondition: where `a` is the created instance, `a.storedType == T.self`, and `a[T.self]`
  ///   is equivalent to `x`.
  init<T>(_ x: T) { storage = x }
  
  /// The type of the value stored in `self`.
  var storedType: Any.Type {
    withUnsafePointer(to: self) {
      // Okay, this is not exactly naive, but it's the only way to get the right semantics, and it's
      // more efficient than type(of: storage) so it's fair to the real AnyValue implementation.
      UnsafeRawPointer($0)
        .assumingMemoryBound(to: (Int,Int,Int, storedType: Any.Type).self).pointee.storedType
    }
  }

  /// Accesses the `T` stored in `self`.
  ///
  /// - Requires: `storedType == T.self`.
  subscript<T>(_: Type<T>) -> T {
    get { storage as! T }
    set { storage = newValue }
  }

  /// Unsafely accesses the `T` stored in `self`.
  ///
  /// - Requires: `storedType == T.self`.
  subscript<T>(unsafelyAssuming _: Type<T>) -> T {
    get { (storage as? T).unsafelyUnwrapped }
    set { storage = newValue }
  }
  
  /// Stores `x` in `self`.
  mutating func store<T>(_ x: T) { storage = x }

  /// The stored value.
  var asAny: Any { storage }
}

/// Type-erased storage substrate based on unconditional boxing of stored values into class
/// instances.
///
/// Note that all dispatching in this file uses the “non-capturing closure” technique from the type
/// erasure survey (https://gist.github.com/dabrahams/c75760b7ed36dd4f039f3679ede825ea), so in no
/// case do we use methods of those classes to capture behavior.  This is just about storage!
internal struct ClassBoxBased_AnyValue: AnyValueProtocol {
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
      assert(!(value is BoxBase), "unexpectedly boxing a box!")
      self.value = value
      super.init(storedType: T.self)
    }

    /// Returns the boxed value.
    fileprivate override var asAny: Any { value }
  }
  
  private var storage: BoxBase
  
  /// Creates an instance that stores `x`.
  ///
  /// - Postcondition: where `a` is the created instance, `a.storedType == T.self`, and `a[T.self]`
  ///   is equivalent to `x`.
  init<T>(_ x: T) { storage = Box(x) }
  
  /// The type of the value stored in `self`.
  var storedType: Any.Type {
    storage.storedType
  }

  /// Accesses the `T` stored in `self`.
  ///
  /// - Requires: `storedType == T.self`.
  subscript<T>(_: Type<T>) -> T {
    get {
      precondition(storedType == T.self)
      return unsafeDowncast(storage, to: Box<T>.self).value
    }
    _modify {
      precondition(storedType == T.self)
      if !isKnownUniquelyReferenced(&storage) {
        storage = Box(unsafeDowncast(storage, to: Box<T>.self).value)
      }
      yield &unsafeDowncast(storage, to: Box<T>.self).value
    }
  }

  /// Unsafely accesses the `T` stored in `self`.
  ///
  /// - Requires: `storedType == T.self`.
  subscript<T>(unsafelyAssuming _: Type<T>) -> T {
    get {
      return unsafeDowncast(storage, to: Box<T>.self).value
    }
    _modify {
      if !isKnownUniquelyReferenced(&storage) {
        cloneStorage(Type<T>())
      }
      yield &unsafeDowncast(storage, to: Box<T>.self).value
    }
  }

  /// Makes the storage uniquely-referenced.
  @inline(never)
  mutating func cloneStorage<T>(_: Type<T>) {
    storage = Box(unsafeDowncast(storage, to: Box<T>.self).value)
  }
  
  /// Stores `x` in `self`.
  mutating func store<T>(_ x: T) {
    if storedType == T.self {
      unsafeDowncast(storage, to: Box<T>.self).value = x
    }
    else {
      storeSlowPath(x)
    }
  }

  @inline(never)
  mutating func storeSlowPath<T>(_ x: T) {
    storage = Box(x)
  }

  /// The stored value.
  var asAny: Any { storage.asAny }
}

/// A type-erased mutable collection similar to the standard library's `AnyCollection`, but with
/// parameterized type-erasure substrate.
fileprivate struct AnyMutableCollection_<Element, Storage: AnyValueProtocol> {
  var storage: Storage
  var vtable: UnsafePointer<VTable>
  
  typealias Self_ = Self
  struct VTable {
    let makeIterator: (Self_) -> Iterator
    let startIndex: (Self_) -> Index
    let endIndex: (Self_) -> Index
    let indexAfter: (Self_, Index) -> Index
    let formIndexAfter: (Self_, inout Index) -> Void
    let subscript_get: (Self_, Index) -> Element
    let subscript_set: (inout Self_, Index, Element) -> Void
    let count: (Self_) -> Int
    // There are many more `Collection` requirements with default implementations that would be
    // optimized if we included them here.
  }
  
  init<C: MutableCollection>(_ x: C) where C.Element == Element {
    storage = Storage(x)
    vtable = demandVTable(.init(Type<Self>.id, Type<C>.id)) {
      VTable(
        makeIterator: { Iterator($0.storage[unsafelyAssuming: Type<C>()].makeIterator()) },
        startIndex: { Index($0.storage[unsafelyAssuming: Type<C>()].startIndex) },
        endIndex: { Index($0.storage[unsafelyAssuming: Type<C>()].endIndex) },
        indexAfter: { self_, index_ in
          Index(
            self_.storage[unsafelyAssuming: Type<C>()]
              .index(after: index_.storage[Type<C.Index>()]))
        },
        formIndexAfter: { self_, index in
          self_.storage[unsafelyAssuming: Type<C>()]
            .formIndex(after: &index.storage[Type<C.Index>()])
        },
        subscript_get: { self_, index in
          self_.storage[unsafelyAssuming: Type<C>()][index.storage[Type<C.Index>()]]
        },
        subscript_set: { self_, index, newValue in
          self_.storage[unsafelyAssuming: Type<C>()][index.storage[Type<C.Index>()]] = newValue
        },
        count: { $0.storage[unsafelyAssuming: Type<C>()].count })
    }
  }
}

extension AnyMutableCollection_: Sequence {
  struct Iterator: IteratorProtocol {
    var storage: Storage
    // There's only one operation, so probably no point bothering with a vtable.
    var next_: (inout Self) -> Element?

    init<T: IteratorProtocol>(_ x: T) where T.Element == Element {
      storage = .init(x)
      next_ = { $0.storage[unsafelyAssuming: Type<T>()].next() }
    }

    mutating func next() -> Element? { next_(&self) }
  }

  func makeIterator() -> Iterator { vtable[0].makeIterator(self) }
}

extension AnyMutableCollection_: MutableCollection {
  struct Index: Comparable {
    var storage: Storage
    // Note: using a vtable here actually made benchmarks slower.  We might want to try again if we
    // expand what the benchmarks are doing.  My hunch is that the cost of copying an Index is less
    // important than the cost of checking for equality.
    var less: (Index, Index) -> Bool
    var equal: (Index, Index) -> Bool

    init<T: Comparable>(_ x: T) {
      storage = .init(x)
      less = {l, r in l.storage[unsafelyAssuming: Type<T>()] < r.storage[Type<T>()]}
      equal = {l, r in l.storage[unsafelyAssuming: Type<T>()] == r.storage[Type<T>()]}
    }

    static func == (lhs: Index, rhs: Index) -> Bool {
      lhs.equal(lhs, rhs)
    }
    
    static func < (lhs: Index, rhs: Index) -> Bool {
      lhs.less(lhs, rhs)
    }
  }

  var startIndex: Index { vtable[0].startIndex(self) }
  
  var endIndex: Index { vtable[0].endIndex(self) }
  
  func index(after x: Index) -> Index { vtable[0].indexAfter(self, x) }
  
  func formIndex(after x: inout Index) { vtable[0].formIndexAfter(self, &x) }
  
  subscript(i: Index) -> Element {
    get { vtable[0].subscript_get(self, i) }
    set { vtable[0].subscript_set(&self, i, newValue) }
  }
  
  var count: Int { vtable[0].count(self) }
}

extension MutableCollection {
  /// Exchanges the first and second halves of `self`, omitting the last element if `count` is odd.
  mutating func swapHalves() {
    let mid = index(startIndex, offsetBy: count / 2)
    var a = startIndex
    var b = mid
    while a != mid && b != endIndex {
      swapAt(a, b)
      formIndex(after: &a)
      formIndex(after: &b)
    }
  }
}

extension AnyValueProtocol {
  /// A standard set of tests for measuring the performance of type erasure.
  static var benchmarks: BenchmarkSuite {
    .init(name: String(describing: self)) { suite in

      func erasedArray(_ n: Int) -> AnyMutableCollection_<Int, Self> {
        hideValue(.init(Array(0..<n)))
      }
      
      suite.benchmark("erased [Int] sum") { state in
        let src = erasedArray(1000000)
        var sum = 0
        try state.measure {
          for x in src { sum += x }
        }
        doNotOptimizeAway(sum)
      }
      
      suite.benchmark("erased [Int] swapHalves") { state in
        var target = erasedArray(10000)
        try state.measure {
          target.swapHalves()
        }
        doNotOptimizeAway(target)
      }
      
      func erasedConcatenatedArrays(_ n: Int) -> AnyMutableCollection_<Int, Self> {
        hideValue(.init(Array(0..<n).concatenated(to: Array(n..<2*n))))
      }
      
      suite.benchmark("erased [Int]x2 sum") { state in
        let src = erasedConcatenatedArrays(100000)
        var sum = 0
        try state.measure {
          for x in src { sum += x }
        }
        doNotOptimizeAway(sum)
      }
      
      suite.benchmark("erased [Int]x2 swapHalves") { state in
        var target = erasedConcatenatedArrays(10000)
        try state.measure {
          target.swapHalves()
        }
        doNotOptimizeAway(target)
      }

      func doubleErasedArrays(_ n: Int) -> AnyMutableCollection_<Int, Self> {
        // This has two levels of type erasure.
        hideValue(.init(erasedConcatenatedArrays(n).concatenated(to: erasedConcatenatedArrays(n))))
      }
      
      suite.benchmark("erased [Int]x4 sum") { state in
        let src = doubleErasedArrays(1000)
        var sum = 0
        try state.measure {
          for x in src { sum += x }
        }
        doNotOptimizeAway(sum)
      }
      
      suite.benchmark("erased [Int]x4 swapHalves") { state in
        var target = doubleErasedArrays(1000)
        try state.measure {
          target.swapHalves()
        }
        doNotOptimizeAway(target)
      }
    }
  }
}
