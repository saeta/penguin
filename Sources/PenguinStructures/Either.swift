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

// TODO: Consider adding `ABiasedEither` and `BBiasedEither` for biased projection wrapper types of
// `Either`.

/// An unbiased [tagged union or sum type](https://en.wikipedia.org/wiki/Tagged_union) of exactly
/// two possible cases.
///
/// **When _NOT_ to use Either**: if there are asymmetrical semantics (e.g. `A` is special in some
/// manner), or when there are better names (i.e. meaning) that can be attached to the cases, a
/// domain-specific `enum` often results in more maintainable code and easier to use APIs.
///
/// **When to use Either**: good applications of `Either` come up in generic programming where there
/// are no defined semantics or information that can be gained from naming or biasing one of the two
/// cases.
public enum Either<A, B> {
  case a(A)
  case b(B)
  /// An `A` if `self` represents the `a` case, `nil` otherwise.
  var a: A? { if case .a(let x) = self { return x } else {return nil } }
  /// A `B` if `self` represents the `b` case, `nil` otherwise.
  var b: B? { if case .b(let x) = self { return x } else {return nil } }
  /// Creates an `Either` from `x` (`a` case).
  public init(_ x: A, or other: Type<B>) { self = .a(x) }
  /// Creates an `Either` from `x` (`a` case).
  public init(_ x: A) { self = .a(x) }
  /// Creates an `Either` from `x` (`b` case).
  public init(_ x: B) { self = .b(x) }
}

extension Either: Equatable where A: Equatable, B: Equatable {
  /// True if `lhs` is equivalent to `rhs`.
  public static func == (lhs: Self, rhs: Self) -> Bool {
    switch (lhs, rhs) {
    case (.a(let lhs), .a(let rhs)): return lhs == rhs
    case (.b(let lhs), .b(let rhs)): return lhs == rhs
    default: return false
    }
  }
}

// Note: while there are other possible orderings that could sense, until Swift has reasonable
// rules and tools to resolve typeclass incoherency, we define a single broadly applicable ordering
// here.
extension Either: Comparable where A: Comparable, B: Comparable {
  /// True iff `lhs` is less than `rhs` such that all `a`s are ordered before all `b`s.
  public static func < (lhs: Self, rhs: Self) -> Bool {
    switch (lhs, rhs) {
    case (.a(let lhs), .a(let rhs)): return lhs < rhs
    case (.a, _): return true
    case (.b(let lhs), .b(let rhs)): return lhs < rhs
    default: return false
    }
  }
}


extension Either: Hashable where A: Hashable, B: Hashable {
  /// Hashes `self` into `hasher`.
  public func hash(into hasher: inout Hasher) {
    switch self {
    case .a(let a): a.hash(into: &hasher)
    case .b(let b): b.hash(into: &hasher)
    }
  }
}

extension Either: CustomStringConvertible {
  /// A textual representation of `self`.
  public var description: String {
    switch self {
    case .a(let a): return "A(\(a))"
    case .b(let b): return "B(\(b))"
    }
  }
}

/// A sequence of one of two sequence types.
///
/// An `EitherSequence` can sometimes be used an alternative to `AnySequence`. Advantages of
/// `EitherSequence` include higher performance, as more information is available at compile time,
/// enabling more effective static optimizations.
///
/// Tip: if code uses `AnySequence`, but most of the time is used with a particular collection type
/// `T` (e.g. `Array<MyThings>`), consider using an `EitherSequence<T, AnySequence>`.
public typealias EitherSequence<A: Sequence, B: Sequence> = Either<A, B>
  where A.Element == B.Element

extension EitherSequence {
  /// A type that provides the sequence’s iteration interface and encapsulates its iteration state.
  public struct Iterator: IteratorProtocol {
    // Note: although we would ideally use `var underlying = Either<A.Iterator, B.Iterator>`, this
    // would result in accidentally quadratic behavior due to the extra copies required. (Enums
    // cannot be modified in-place, resulting in a lot of extra copies.)
    //
    // Future optimization: avoid needing to reserve space for both `a` and `b` iterators.

    /// An iterator for the `A` collection.
    var a: A.Iterator?
    /// An iterator for the `A` collection.
    var b: B.Iterator?

    /// The type of element traversed by the iterator.
    public typealias Element = A.Element

    /// Advances to the next element and returns it, or `nil` if no next element exists.
    public mutating func next() -> Element? {
      a?.next() ?? b?.next()
    }
  }
}

extension EitherSequence: Sequence {
  /// A type representing the sequence’s elements.
  public typealias Element = A.Element

  /// Returns an iterator over the elements of this sequence.
  public func makeIterator() -> Iterator {
    switch self {
    case .a(let a): return Iterator(a: a.makeIterator(), b: nil)
    case .b(let b): return Iterator(a: nil, b: b.makeIterator())
    }
  }
}

/// A collection of one of two collection types.
///
/// - SeeAlso: `EitherSequence`.
public typealias EitherCollection<A: Collection, B: Collection> = Either<A, B>
  where A.Element == B.Element

extension EitherCollection: Collection {
  /// A type that represents a position in the collection.
  public typealias Index = Either<A.Index, B.Index>

  /// The position of the first element in a nonempty collection.
  public var startIndex: Index {
    switch self {
    case .a(let c): return Index(c.startIndex)
    case .b(let c): return Index(c.startIndex)
    }
  }

  /// The collection’s “past the end” position—that is, the position one greater than the last valid
  /// subscript argument.
  public var endIndex: Index {
    switch self {
    case .a(let c): return Index(c.endIndex)
    case .b(let c): return Index(c.endIndex)
    }
  }

  /// Returns the position immediately after the given index.
  public func index(after i: Index) -> Index {
    switch (i, self) {
    case (.a(let i), .a(let c)): return Index(c.index(after: i))
    case (.b(let i), .b(let c)): return Index(c.index(after: i))
    default: fatalError("Invalid index \(i) used with \(self).")
    }
  }

  /// Accesses the element at the specified position.
  public subscript(position: Index) -> Element {
    switch (position, self) {
    case (.a(let i), .a(let c)): return c[i]
    case (.b(let i), .b(let c)): return c[i]
    default: fatalError("Invalid index \(position) used with \(self).")
    }
  }
}

// TODO: Bidirectional & RandomAccess conformances & verification tests!
