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

/// Statically-sized nonempty collections of homogeneous elements.
///
/// This protocol is mostly an implementation detail of `ArrayN`; it is not
/// generally useful.  Unless you're interested in generic application of
/// `inserting`/`removing`, you probably want to use
/// `RandomAccessCollection`/`MutableCollection` (either as constraints or
/// conformances).
///
/// The models of `FixedSizeArray` defined here efficiently support producing
/// new instances by single-element insertion and deletion.
public protocol FixedSizeArray:
  MutableCollection, RandomAccessCollection, SourceInitializableCollection,
  CustomStringConvertible where Index == Int
{
  /// Creates an instance containing exactly the elements of `source`.
  ///
  /// Requires: `source.count == c`, where `c` is the capacity of instances.
  init<Source: Collection>(_ source: Source) where Source.Element == Element
  // Note: we don't have a generalization to `Sequence` because we couldn't
  // find an implementation optimizes nearly as well, and in practice
  // `Sequence`'s that are not `Collection`s are extremely rare.

  /// Creates an instance containing the elements of `source` except the one
  /// at `targetPosition`.
  ///
  /// Requires: `source.indices.contains(targetPosition)`
  init(_ source: ArrayN<Self>, removingAt targetPosition: Index)
  
  /// Returns a fixed-sized collection containing the same elements as `self`,
  /// with `newElement` inserted at `targetPosition`.
  func inserting(_ newElement: Element, at targetPosition: Index) -> ArrayN<Self>

  /// The number of elements in an instance.
  static var count: Int { get }
}

public extension FixedSizeArray {
  /// Default implementation of `CustomStringConvertible` conformance.
  var description: String { "\(Array(self))"}

  /// Returns the result of calling `body` on the elements of `self`.
  func withUnsafeBufferPointer<R>(
    _ body: (UnsafeBufferPointer<Element>) throws -> R
  ) rethrows -> R {
    return try withUnsafePointer(to: self) { [count] p in
      try body(
          UnsafeBufferPointer<Element>(
              start: UnsafeRawPointer(p)
                  .assumingMemoryBound(to: Element.self),
              count: count))
    }
  }

  /// Returns the result of calling `body` on the elements of `self`.
  mutating func withUnsafeMutableBufferPointer<R>(
    _ body: (inout UnsafeMutableBufferPointer<Element>) throws -> R
  ) rethrows -> R {
    return try withUnsafeMutablePointer(to: &self) { [count] p in
      var b = UnsafeMutableBufferPointer<Element>(
        start: UnsafeMutableRawPointer(p)
          .assumingMemoryBound(to: Element.self),
        count: count)
      return try body(&b)
    }
  }

  /// Returns the result of calling `body` on the elements of `self`.
  func withContiguousStorageIfAvailable<R>(
    _ body: (UnsafeBufferPointer<Element>) throws -> R
  ) rethrows -> R? {
    return try withUnsafeBufferPointer(body)
  }

  /// Returns the result of calling `body` on the elements of `self`.
  mutating func withContiguousMutableStorageIfAvailable<R>(
    _ body: (inout UnsafeMutableBufferPointer<Element>) throws -> R
  ) rethrows -> R? {
    return try withUnsafeMutableBufferPointer(body)
  }


  /// Returns a fixed-sized collection containing the same elements as `self`,
  /// with `newElement` inserted at the start.
  func prepending(_ newElement: Element) -> ArrayN<Self> {
    .init(head: newElement, tail: self)
  }
}

/// A fixed sized collection of 0 elements.
public struct Array0<T> : FixedSizeArray {
  public init() {  }
  
  /// Creates an instance containing exactly the elements of `source`.
  ///
  /// Requires: `source.isEmpty`
  @inline(__always)
  public init<Source: Collection>(_ source: Source)
      where Source.Element == Element
  {
    precondition(source.isEmpty, "Too many elements in source")
  }
  
  /// Creates an instance containing the elements of `source` except the one
  /// at `targetPosition`.
  ///
  /// Requires: `source.indices.contains(targetPosition)`
  public init(_ source: ArrayN<Self>, removingAt targetPosition: Index) {
    precondition(targetPosition == 0, "Index out of range.")
    self.init()
  }

  /// Returns a fixed-sized collection containing the same elements as `self`,
  /// with `newElement` inserted at `targetPosition`.
  public func inserting(_ newElement: Element, at i: Index) -> ArrayN<Self> {
    precondition(i == 0, "Index out of range.")
    return .init(head: newElement, tail: self)
  }

  /// The number of elements in an instance.
  public static var count: Int { 0 }

  // ======== Collection Requirements ============
  public typealias Index = Int
  
  /// Accesses the element at `i`.
  public subscript(i: Index) -> T {
    get { fatalError("index out of range") }
    set { fatalError("index out of range") }
  }
  
  /// The position of the first element.
  public var startIndex: Index { 0 }
  
  /// The position just past the last element.
  public var endIndex: Index { 0 }
}

// ----- Standard conditional conformances. -------
extension Array0 : Equatable where T : Equatable {}
extension Array0 : Hashable where T : Hashable {}
extension Array0 : Comparable where Element : Comparable {
  public static func < (l: Self, r: Self) -> Bool { return false }
}

/// A fixed sized random access collection one element longer than `Tail`,
/// supporting efficient creation of instances of related types via
/// single-element insertion and deletion.
public struct ArrayN<Tail: FixedSizeArray> : FixedSizeArray {
  private var head: Element
  private var tail: Tail
  
  public typealias Element = Tail.Element

  /// Creates an instance containing exactly the elements of `source`.
  ///
  /// Requires: `source.count == c`, where `c` is the capacity of instances.
  @inline(__always)
  public init<Source: Collection>(_ source: Source)
      where Source.Element == Element
  {
    head = source.first!
    tail = .init(source.dropFirst())
  }

  /// Creates an instance containing `head` followed by the contents of
  /// `tail`.
  // Could be private, but for a test that is using it.
  internal init(head: Element, tail: Tail) {
    self.head = head
    self.tail = tail
  }

  /// Creates an instance containing the elements of `source` except the one at
  /// `targetPosition`.
  ///
  /// Requires: `source.indices.contains(targetPosition)`
  public init(_ source: ArrayN<Self>, removingAt targetPosition: Index) {
    self = targetPosition == 0
        ? source.tail
        : Self(
            head: source.head,
            tail: .init(source.tail, removingAt: targetPosition &- 1))
  }
  
  /// Returns a fixed-sized collection containing the same elements as `self`,
  /// with `newElement` inserted at `targetPosition`.
  public func inserting(_ newElement: Element, at i: Index) -> ArrayN<Self> {
    if i == 0 { return .init(head: newElement, tail: self) }
    return .init(head: head, tail: tail.inserting(newElement, at: i &- 1))
  }

  /// Returns a fixed-sized collection containing the elements of self
  /// except the one at `targetPosition`.
  ///
  /// Requires: `indices.contains(targetPosition)`
  public func removing(at targetPosition: Index) -> Tail {
    .init(self, removingAt: targetPosition)
  }

  /// Traps with a suitable error message if `i` is not the position of an
  /// element in `self`.
  private func boundsCheck(_ i: Int) {
    precondition(i >= 0 && i < count, "index out of range")
  }

  /// The number of elements in an instance.
  public static var count: Int { Tail.count &+ 1 }
  
  // ======== Collection Requirements ============
  /// Returns the element at `i`.
  public subscript(i: Int) -> Element {
    _read {
      boundsCheck(i)
      yield withUnsafeBufferPointer { $0.baseAddress.unsafelyUnwrapped[i] }
    }
    _modify {
      boundsCheck(i)
      defer { _fixLifetime(self) }
      yield &withUnsafeMutableBufferPointer {
        $0.baseAddress
      }.unsafelyUnwrapped[i]
    }
  }
  
  /// The position of the first element.
  public var startIndex: Int { 0 }
  /// The position just past the last element.
  public var endIndex: Int { tail.endIndex &+ 1 }
}

// ======== Conveniences ============

public typealias Array1<T> = ArrayN<Array0<T>>
public typealias Array2<T> = ArrayN<Array1<T>>
public typealias Array3<T> = ArrayN<Array2<T>>
public typealias Array4<T> = ArrayN<Array3<T>>
public typealias Array5<T> = ArrayN<Array4<T>>
public typealias Array6<T> = ArrayN<Array5<T>>
public typealias Array7<T> = ArrayN<Array6<T>>

public extension ArrayN {
  /// Creates `Self([a0, a1])` efficiently.
  init<T>(_ a0: T, _ a1: T) where Tail == Array1<T> {
    head = a0; tail = Array1(CollectionOfOne(a1))
  }
  /// Creates `Self([a0, a1, a2])` efficiently.
  init<T>(_ a0: T, _ a1: T, _ a2: T) where Tail == Array2<T> {
    head = a0; tail = Array2(a1, a2)
  }
  /// Creates `Self([a0, a1, a2, a3])` efficiently.
  init<T>(_ a0: T, _ a1: T, _ a2: T, _ a3: T) where Tail == Array3<T> {
    head = a0; tail = Tail(a1, a2, a3)
  }
  /// Creates `Self([a0, a1, a2, a3, a4])` efficiently.
  init<T>(_ a0: T, _ a1: T, _ a2: T, _ a3: T, _ a4: T) where Tail == Array4<T>
  {
    head = a0; tail = Tail(a1, a2, a3, a4)
  }
  /// Creates `Self([a0, a1, a2, a3, a4, a5])` efficiently.
  init<T>(_ a0: T, _ a1: T, _ a2: T, _ a3: T, _ a4: T, _ a5: T)
      where Tail == Array5<T>
  {
    head = a0; tail = Tail(a1, a2, a3, a4, a5)
  }
  /// Creates `Self([a0, a1, a2, a3, a4, a6])` efficiently.
  init<T>(_ a0: T, _ a1: T, _ a2: T, _ a3: T, _ a4: T, _ a5: T, _ a6: T)
      where Tail == Array6<T>
  {
    head = a0; tail = Tail(a1, a2, a3, a4, a5, a6)
  }
}

// ----- Standard conditional conformances. -------
extension ArrayN : Equatable
  where Element : Equatable, Tail : Equatable {}
extension ArrayN : Hashable
  where Element : Hashable, Tail : Hashable {}
extension ArrayN : Comparable
  where Element : Comparable, Tail : Comparable {
  public static func < (l: Self, r: Self) -> Bool {
    l.head < r.head || !(l.head > r.head) && l.tail < r.tail
  }
}
